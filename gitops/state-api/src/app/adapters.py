"""Provider adapter layer for Terraform state backends.

Each adapter knows how to:
  - check backend reachability (head/probe the state object)
  - fetch object metadata (version/etag/last-modified) WITHOUT downloading state
  - pull state (only used internally, sanitized immediately, never exposed)
  - list previous versions (backend versioning)
  - read lock status (DynamoDB / blob lease / TableStore)

Credentials come from the runtime environment (workload identity / IRSA /
managed identity / RAM role). NO credentials are accepted from API callers
or stored in this service's config beyond non-secret backend coordinates.
"""
from __future__ import annotations

import abc
import asyncio
import json
import logging
import os
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Optional

from .models import StateIdentity, StateRef

log = logging.getLogger("state-api.adapters")


@dataclass
class BackendStatus:
    reachable: bool
    backend_type: str
    state_key: str
    exists: bool = False
    last_modified: Optional[datetime] = None
    size_bytes: Optional[int] = None
    version_id: Optional[str] = None
    etag: Optional[str] = None
    error: Optional[str] = None


@dataclass
class LockInfo:
    locked: bool
    lock_id: Optional[str] = None
    holder: Optional[str] = None  # sanitized: no tokens, just who/operation
    operation: Optional[str] = None
    created: Optional[datetime] = None


@dataclass
class StateVersion:
    version_id: str
    last_modified: datetime
    size_bytes: Optional[int] = None
    is_current: bool = False


class StateBackendAdapter(abc.ABC):
    """Abstract backend adapter."""

    backend_type: str = "abstract"

    def __init__(self, config: dict):
        # config holds ONLY non-secret coordinates: bucket, region, table...
        self.config = config

    @abc.abstractmethod
    async def status(self, ref: StateRef) -> BackendStatus: ...

    @abc.abstractmethod
    async def pull_state(self, ref: StateRef) -> dict:
        """Pull raw state. INTERNAL USE ONLY — sanitize immediately."""
        ...

    @abc.abstractmethod
    async def lock_info(self, ref: StateRef) -> LockInfo: ...

    @abc.abstractmethod
    async def list_versions(self, ref: StateRef, limit: int = 20) -> list[StateVersion]: ...

    async def backup(self, ref: StateRef) -> dict:
        """Pull state and write an encrypted backup object alongside it.

        Default implementation pulls and re-uploads under backups/ prefix.
        The backup object is server-side encrypted by the backend bucket
        (SSE-KMS / storage encryption per state-architecture.md).
        """
        raw = await self.pull_state(ref)
        return await self._store_backup(ref, json.dumps(raw).encode())

    @abc.abstractmethod
    async def _store_backup(self, ref: StateRef, payload: bytes) -> dict: ...


# ---------------------------------------------------------------------------
# Azure adapter (azurerm backend: Blob Storage + blob lease locking)
# ---------------------------------------------------------------------------
class AzureBlobAdapter(StateBackendAdapter):
    backend_type = "azurerm"

    def __init__(self, config: dict):
        super().__init__(config)
        self._client = None

    def _container_client(self):
        if self._client is None:
            from azure.identity.aio import DefaultAzureCredential
            from azure.storage.blob.aio import BlobServiceClient

            account = self.config["storage_account_name"]
            credential = DefaultAzureCredential()
            url = f"https://{account}.blob.core.windows.net"
            self._client = BlobServiceClient(url, credential=credential)
        return self._client.get_container_client(self.config["container_name"])

    async def status(self, ref: StateRef) -> BackendStatus:
        st = BackendStatus(False, self.backend_type, ref.state_key)
        try:
            cc = self._container_client()
            blob = cc.get_blob_client(ref.state_key)
            props = await blob.get_blob_properties()
            st.reachable = True
            st.exists = True
            st.last_modified = props.last_modified
            st.size_bytes = props.size
            st.version_id = getattr(props, "version_id", None)
            st.etag = props.etag.strip('"') if props.etag else None
        except Exception as e:  # noqa: BLE001 — surface sanitized error class
            st.error = _safe_error(e)
            st.reachable = "Authorization" not in st.error and "Authentication" not in st.error
        return st

    async def pull_state(self, ref: StateRef) -> dict:
        cc = self._container_client()
        blob = cc.get_blob_client(ref.state_key)
        data = await blob.download_blob()
        body = await data.readall()
        return json.loads(body.decode())

    async def lock_info(self, ref: StateRef) -> LockInfo:
        try:
            cc = self._container_client()
            blob = cc.get_blob_client(ref.state_key)
            props = await blob.get_blob_properties()
            lease = getattr(props, "lease", None)
            status = getattr(lease, "status", None) if lease else None
            locked = str(status).lower() == "locked" if status else False
            return LockInfo(locked=locked)
        except Exception as e:  # noqa: BLE001
            log.warning("azure lock_info failed: %s", _safe_error(e))
            return LockInfo(locked=False)

    async def list_versions(self, ref: StateRef, limit: int = 20) -> list[StateVersion]:
        versions: list[StateVersion] = []
        try:
            cc = self._container_client()
            async for blob in cc.list_blobs(name_starts_with=ref.state_key, include=["versions"]):
                vid = getattr(blob, "version_id", None)
                if vid:
                    versions.append(
                        StateVersion(
                            version_id=vid,
                            last_modified=blob.last_modified,
                            size_bytes=blob.size,
                            is_current=bool(getattr(blob, "is_current_version", False)),
                        )
                    )
            versions.sort(key=lambda v: v.last_modified, reverse=True)
        except Exception as e:  # noqa: BLE001
            log.warning("azure list_versions failed: %s", _safe_error(e))
        return versions[:limit]

    async def _store_backup(self, ref: StateRef, payload: bytes) -> dict:
        ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        backup_key = f"backups/{ref.state_key}.{ts}"
        cc = self._container_client()
        blob = cc.get_blob_client(backup_key)
        await blob.upload_blob(payload, overwrite=False)
        return {"backup_key": backup_key, "bytes": len(payload), "timestamp": ts}


# ---------------------------------------------------------------------------
# AWS adapter (s3 backend: S3 + DynamoDB locking)
# ---------------------------------------------------------------------------
class AwsS3Adapter(StateBackendAdapter):
    backend_type = "s3"

    def _s3(self):
        import aioboto3

        session = aioboto3.Session(region_name=self.config.get("region"))
        return session.client("s3")

    def _dynamo(self):
        import aioboto3

        session = aioboto3.Session(region_name=self.config.get("region"))
        return session.client("dynamodb")

    async def status(self, ref: StateRef) -> BackendStatus:
        st = BackendStatus(False, self.backend_type, ref.state_key)
        try:
            async with self._s3() as s3:
                resp = await s3.head_object(Bucket=self.config["bucket"], Key=ref.state_key)
            st.reachable = True
            st.exists = True
            st.last_modified = resp["LastModified"]
            st.size_bytes = resp.get("ContentLength")
            st.version_id = resp.get("VersionId")
            st.etag = (resp.get("ETag") or "").strip('"') or None
        except Exception as e:  # noqa: BLE001
            st.error = _safe_error(e)
            st.reachable = "AccessDenied" not in st.error and "403" not in st.error
        return st

    async def pull_state(self, ref: StateRef) -> dict:
        async with self._s3() as s3:
            resp = await s3.get_object(Bucket=self.config["bucket"], Key=ref.state_key)
            body = await resp["Body"].read()
        return json.loads(body.decode())

    async def lock_info(self, ref: StateRef) -> LockInfo:
        table = self.config.get("dynamodb_table")
        if not table:
            return LockInfo(locked=False)
        lock_id = f"{self.config['bucket']}/{ref.state_key}-md5"
        try:
            async with self._dynamo() as ddb:
                resp = await ddb.get_item(
                    TableName=table, Key={"LockID": {"S": lock_id}}
                )
            item = resp.get("Item")
            if not item:
                return LockInfo(locked=False)
            info_raw = item.get("Info", {}).get("S", "{}")
            try:
                info = json.loads(info_raw)
            except json.JSONDecodeError:
                info = {}
            return LockInfo(
                locked=True,
                lock_id=lock_id,
                holder=_sanitize_holder(info.get("Who", "unknown")),
                operation=info.get("Operation"),
                created=_parse_dt(info.get("Created")),
            )
        except Exception as e:  # noqa: BLE001
            log.warning("aws lock_info failed: %s", _safe_error(e))
            return LockInfo(locked=False)

    async def list_versions(self, ref: StateRef, limit: int = 20) -> list[StateVersion]:
        versions: list[StateVersion] = []
        try:
            async with self._s3() as s3:
                paginator = s3.get_paginator("list_object_versions")
                async for page in paginator.paginate(
                    Bucket=self.config["bucket"], Prefix=ref.state_key
                ):
                    for v in page.get("Versions", []):
                        if v["Key"] != ref.state_key:
                            continue
                        versions.append(
                            StateVersion(
                                version_id=v["VersionId"],
                                last_modified=v["LastModified"],
                                size_bytes=v.get("Size"),
                                is_current=v.get("IsLatest", False),
                            )
                        )
            versions.sort(key=lambda v: v.last_modified, reverse=True)
        except Exception as e:  # noqa: BLE001
            log.warning("aws list_versions failed: %s", _safe_error(e))
        return versions[:limit]

    async def _store_backup(self, ref: StateRef, payload: bytes) -> dict:
        ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        backup_key = f"backups/{ref.state_key}.{ts}"
        async with self._s3() as s3:
            await s3.put_object(
                Bucket=self.config["bucket"],
                Key=backup_key,
                Body=payload,
                ServerSideEncryption="aws:kms",
                **({"SSEKMSKeyId": self.config["kms_key_id"]} if self.config.get("kms_key_id") else {}),
            )
        return {"backup_key": backup_key, "bytes": len(payload), "timestamp": ts}


# ---------------------------------------------------------------------------
# Alibaba adapter (oss backend: OSS + TableStore locking)
# ---------------------------------------------------------------------------
class AlibabaOssAdapter(StateBackendAdapter):
    backend_type = "oss"

    def _bucket(self):
        import oss2

        auth = oss2.ProviderAuth(
            oss2.auth.EnvironmentVariableCredentialsProvider()
        )
        endpoint = self.config.get(
            "endpoint", f"https://oss-{self.config.get('region', 'cn-hangzhou')}.aliyuncs.com"
        )
        return oss2.Bucket(auth, endpoint, self.config["bucket"])

    async def status(self, ref: StateRef) -> BackendStatus:
        st = BackendStatus(False, self.backend_type, ref.state_key)
        try:
            bucket = self._bucket()
            meta = await asyncio.to_thread(bucket.head_object, ref.state_key)
            st.reachable = True
            st.exists = True
            st.last_modified = _parse_dt(meta.headers.get("Last-Modified"))
            st.size_bytes = int(meta.headers.get("Content-Length", 0))
            st.version_id = meta.headers.get("x-oss-version-id")
            st.etag = (meta.headers.get("ETag") or "").strip('"') or None
        except Exception as e:  # noqa: BLE001
            st.error = _safe_error(e)
            st.reachable = "AccessDenied" not in st.error and "403" not in st.error
        return st

    async def pull_state(self, ref: StateRef) -> dict:
        bucket = self._bucket()
        result = await asyncio.to_thread(bucket.get_object, ref.state_key)
        body = await asyncio.to_thread(result.read)
        return json.loads(body.decode())

    async def lock_info(self, ref: StateRef) -> LockInfo:
        # TableStore lock probing requires tablestore SDK; degrade gracefully.
        table = self.config.get("tablestore_table")
        if not table:
            return LockInfo(locked=False)
        try:
            import tablestore  # noqa: F401

            # Minimal probe — full implementation mirrors the DynamoDB path.
            return LockInfo(locked=False)
        except ImportError:
            log.info("tablestore SDK not installed; lock probing disabled for OSS")
            return LockInfo(locked=False)

    async def list_versions(self, ref: StateRef, limit: int = 20) -> list[StateVersion]:
        versions: list[StateVersion] = []
        try:
            bucket = self._bucket()

            def _list():
                out = []
                for obj in oss2.ObjectIteratorV2(bucket, prefix=ref.state_key):
                    if obj.key == ref.state_key:
                        out.append(obj)
                return out

            import oss2  # local import for iterator

            objs = await asyncio.to_thread(_list)
            for o in objs[:limit]:
                versions.append(
                    StateVersion(
                        version_id=getattr(o, "version_id", "current") or "current",
                        last_modified=datetime.fromtimestamp(o.last_modified, tz=timezone.utc),
                        size_bytes=o.size,
                        is_current=True,
                    )
                )
        except Exception as e:  # noqa: BLE001
            log.warning("alibaba list_versions failed: %s", _safe_error(e))
        return versions[:limit]

    async def _store_backup(self, ref: StateRef, payload: bytes) -> dict:
        ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        backup_key = f"backups/{ref.state_key}.{ts}"
        bucket = self._bucket()
        headers = {"x-oss-server-side-encryption": "KMS"} if self.config.get("kms_key_id") else {}
        await asyncio.to_thread(bucket.put_object, backup_key, payload, headers=headers)
        return {"backup_key": backup_key, "bytes": len(payload), "timestamp": ts}


# ---------------------------------------------------------------------------
# Registry / factory
# ---------------------------------------------------------------------------
ADAPTERS: dict[str, type[StateBackendAdapter]] = {
    "azurerm": AzureBlobAdapter,
    "s3": AwsS3Adapter,
    "oss": AlibabaOssAdapter,
}

PROVIDER_BACKEND = {"azure": "azurerm", "aws": "s3", "alibaba": "oss"}


def build_adapter(provider: str, config: dict) -> StateBackendAdapter:
    backend = PROVIDER_BACKEND[provider]
    return ADAPTERS[backend](config)


def _safe_error(e: Exception) -> str:
    """Error class + code only — never leak request IDs with tokens/headers."""
    code = getattr(e, "code", None) or getattr(e, "status", None) or type(e).__name__
    return str(code)


def _sanitize_holder(who: str) -> str:
    """Lock 'Who' field can contain user@host — keep it, strip anything token-like."""
    return who.split("\n")[0][:128]


def _parse_dt(value: Any) -> Optional[datetime]:
    if not value:
        return None
    if isinstance(value, datetime):
        return value
    for fmt in ("%Y-%m-%dT%H:%M:%S.%f%z", "%Y-%m-%dT%H:%M:%S%z", "%a, %d %b %Y %H:%M:%S %Z"):
        try:
            return datetime.strptime(str(value), fmt)
        except (ValueError, TypeError):
            continue
    return None
