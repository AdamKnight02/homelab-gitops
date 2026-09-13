"""state-api — safe Terraform state metadata service.

SECURITY MODEL
- Never returns raw state. All state content passes through sanitize.py.
- Auth required on every endpoint (OIDC or K8s TokenReview).
- Read-only by default (state-viewer). Mutating-adjacent actions
  (validate/drift/backup) require state-operator. Migration initiation
  requires state-privileged AND creates an approval request — this service
  never runs terraform state rm/push/force-unlock.
- Every request emits an audit event with a correlation id.
"""
from __future__ import annotations

import asyncio
import logging
import os
import time
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import Depends, FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse

from . import metrics
from .adapters import StateBackendAdapter
from .audit import audit_event, new_correlation_id
from .auth import (
    ROLE_OPERATOR,
    ROLE_PRIVILEGED,
    Principal,
    get_principal,
    require_role,
)
from .models import StateIdentity
from .registry import registry
from .sanitize import state_metadata_from_raw

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
log = logging.getLogger("state-api")

# In-memory caches (short TTL; metadata only — never raw state)
_status_cache: dict[str, tuple[float, dict]] = {}
_metadata_cache: dict[str, tuple[float, dict]] = {}
_drift_results: dict[str, dict] = {}
_migration_requests: dict[str, dict] = {}
STATUS_TTL = int(os.getenv("STATUS_CACHE_TTL", "60"))
METADATA_TTL = int(os.getenv("METADATA_CACHE_TTL", "300"))


@asynccontextmanager
async def lifespan(app: FastAPI):
    task = asyncio.create_task(_metrics_refresher())
    yield
    task.cancel()


app = FastAPI(
    title="PKI Platform State API",
    version="1.0.0",
    description="Sanitized Terraform state metadata, health, locks, versions, drift, migrations.",
    lifespan=lifespan,
    docs_url=None,  # no public swagger; internal service
    redoc_url=None,
    openapi_url=None,
)

# Internal-only by default; CORS restricted to the state-ui origin.
_ui_origin = os.getenv("STATE_UI_ORIGIN", "http://state-ui.state-system.svc.cluster.local")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[_ui_origin],
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type", "X-Correlation-ID"],
    max_age=600,
)


# ---------------------------------------------------------------------------
# Health (unauthenticated — used by kubelet probes; exposes nothing)
# ---------------------------------------------------------------------------
@app.get("/healthz")
async def healthz():
    return {"status": "ok"}


@app.get("/livez")
async def livez():
    return {"status": "alive"}


@app.get("/metrics")
async def metrics_endpoint(principal: Principal = Depends(get_principal)):
    return PlainTextResponse(metrics.render().decode(), media_type="text/plain; version=0.0.4")


# ---------------------------------------------------------------------------
# Inventory
# ---------------------------------------------------------------------------
@app.get("/api/v1/states")
async def list_states(request: Request, principal: Principal = Depends(get_principal)):
    """List all registered state identities with summary health."""
    cid = new_correlation_id()
    out = []
    for ident in registry.list_identities():
        summary = await _get_status_summary(ident.slug)
        out.append(
            {
                "identity": ident.slug,
                "provider": ident.provider,
                "customer": ident.customer,
                "environment": ident.environment,
                "component": ident.component,
                "backend_type": summary.get("backend_type"),
                "state_key": ident.state_key,
                "reachable": summary.get("reachable"),
                "locked": summary.get("locked"),
                "last_modified": summary.get("last_modified"),
                "health": _health_of(summary),
            }
        )
    audit_event(action="list_states", subject=principal.subject, correlation_id=cid,
                detail={"count": len(out)})
    return {"states": out, "correlation_id": cid}


@app.get("/api/v1/states/{provider}/{customer}/{environment}/{component}")
async def get_state_detail(
    provider: str,
    customer: str,
    environment: str,
    component: str,
    principal: Principal = Depends(get_principal),
):
    """Full sanitized detail for one state: metadata + health + lock + drift."""
    slug = f"{provider}/{customer}/{environment}/{component}"
    resolved = registry.resolve(slug)
    if not resolved:
        raise HTTPException(404, "state not registered")
    ref, adapter, pipeline = resolved
    cid = new_correlation_id()

    status = await adapter.status(ref)
    lock = await adapter.lock_info(ref)
    drift = _drift_results.get(slug)

    detail = {
        "identity": slug,
        "provider": provider,
        "customer": customer,
        "environment": environment,
        "component": component,
        "backend": {
            "type": ref.backend_type,
            "state_key": ref.state_key,
            # coordinates only — never credentials
            "config": {k: v for k, v in ref.backend_config.items()
                       if k not in ("access_key", "secret_key", "sas_token", "key")},
        },
        "health": {
            "reachable": status.reachable,
            "exists": status.exists,
            "error": status.error,
            "last_modified": _iso(status.last_modified),
            "size_bytes": status.size_bytes,
            "version_id": status.version_id,
        },
        "lock": {
            "locked": lock.locked,
            "holder": lock.holder,
            "operation": lock.operation,
            "created": _iso(lock.created),
        },
        "drift": drift,
        "pipeline": {
            "url": pipeline.get("url"),
            "last_run_id": pipeline.get("last_run_id"),
            "last_run_status": pipeline.get("last_run_status"),
            "last_run_time": pipeline.get("last_run_time"),
        },
        "correlation_id": cid,
    }
    audit_event(action="get_state_detail", subject=principal.subject, identity=slug,
                correlation_id=cid)
    return detail


@app.get("/api/v1/states/{provider}/{customer}/{environment}/{component}/metadata")
async def get_state_metadata(
    provider: str,
    customer: str,
    environment: str,
    component: str,
    principal: Principal = Depends(get_principal),
):
    """Sanitized state metadata: version, serial, resource counts, safe outputs.

    Raw state is pulled, sanitized in-memory, and discarded. NEVER returned.
    """
    slug = f"{provider}/{customer}/{environment}/{component}"
    resolved = registry.resolve(slug)
    if not resolved:
        raise HTTPException(404, "state not registered")
    ref, adapter, _ = resolved
    cid = new_correlation_id()

    cached = _metadata_cache.get(slug)
    if cached and time.time() - cached[0] < METADATA_TTL:
        meta = cached[1]
        meta["cache"] = "hit"
    else:
        raw = await adapter.pull_state(ref)
        meta = state_metadata_from_raw(raw, slug)
        del raw  # discard immediately
        meta["cache"] = "miss"
        _metadata_cache[slug] = (time.time(), meta)
        # update gauges
        lbl = metrics.labels_for(ref.identity)
        if meta.get("serial") is not None:
            metrics.version.labels(**lbl).set(meta["serial"])
        metrics.resource_count.labels(**lbl).set(meta["resources"]["managed_count"])

    meta["correlation_id"] = cid
    audit_event(action="view_metadata", subject=principal.subject, identity=slug,
                correlation_id=cid)
    return meta


@app.get("/api/v1/states/{provider}/{customer}/{environment}/{component}/versions")
async def get_state_versions(
    provider: str,
    customer: str,
    environment: str,
    component: str,
    principal: Principal = Depends(get_principal),
):
    slug = f"{provider}/{customer}/{environment}/{component}"
    resolved = registry.resolve(slug)
    if not resolved:
        raise HTTPException(404, "state not registered")
    ref, adapter, _ = resolved
    cid = new_correlation_id()
    versions = await adapter.list_versions(ref)
    audit_event(action="view_version_history", subject=principal.subject,
                identity=slug, correlation_id=cid, detail={"count": len(versions)})
    return {
        "identity": slug,
        "versions": [
            {
                "version_id": v.version_id,
                "last_modified": _iso(v.last_modified),
                "size_bytes": v.size_bytes,
                "is_current": v.is_current,
            }
            for v in versions
        ],
        "correlation_id": cid,
    }


# ---------------------------------------------------------------------------
# Safe actions
# ---------------------------------------------------------------------------
@app.post("/api/v1/states/{provider}/{customer}/{environment}/{component}/validate")
async def validate_state(
    provider: str,
    customer: str,
    environment: str,
    component: str,
    principal: Principal = Depends(require_role(ROLE_OPERATOR)),
):
    """Validate state: pull, parse, check integrity (serial/lineage present,
    resources parseable). Does NOT modify anything."""
    slug = f"{provider}/{customer}/{environment}/{component}"
    resolved = registry.resolve(slug)
    if not resolved:
        raise HTTPException(404, "state not registered")
    ref, adapter, _ = resolved
    cid = new_correlation_id()
    try:
        raw = await adapter.pull_state(ref)
        meta = state_metadata_from_raw(raw, slug)
        del raw
        ok = all(
            meta.get(k) is not None for k in ("version", "serial", "lineage")
        )
        result = {
            "valid": ok,
            "checks": {
                "parseable": True,
                "has_version": meta.get("version") is not None,
                "has_serial": meta.get("serial") is not None,
                "has_lineage": meta.get("lineage") is not None,
                "terraform_version": meta.get("terraform_version"),
                "resource_count": meta["resources"]["managed_count"],
            },
        }
        audit_event(action="validate_state", subject=principal.subject, identity=slug,
                    outcome="success" if ok else "failed", correlation_id=cid)
        return {**result, "correlation_id": cid}
    except Exception as e:  # noqa: BLE001
        audit_event(action="validate_state", subject=principal.subject, identity=slug,
                    outcome="error", correlation_id=cid,
                    detail={"error": type(e).__name__})
        raise HTTPException(502, f"validation failed: {type(e).__name__}")


@app.post("/api/v1/states/{provider}/{customer}/{environment}/{component}/drift-check")
async def run_drift_detection(
    provider: str,
    customer: str,
    environment: str,
    component: str,
    principal: Principal = Depends(require_role(ROLE_OPERATOR)),
):
    """Record a drift-detection request.

    Actual `terraform plan -detailed-exitcode` runs in the PIPELINE (which has
    cloud credentials and write access to report back). This endpoint creates
    an auditable request and returns the pending status; the pipeline updates
    drift status via the privileged report endpoint. This keeps cloud write
    credentials out of the UI service entirely.
    """
    slug = f"{provider}/{customer}/{environment}/{component}"
    resolved = registry.resolve(slug)
    if not resolved:
        raise HTTPException(404, "state not registered")
    cid = new_correlation_id()
    _drift_results[slug] = {
        "status": "requested",
        "requested_by": principal.subject,
        "requested_at": _iso(datetime.now(timezone.utc)),
        "drift_detected": None,
        "note": "Drift detection executes in the deployment pipeline; results are reported back.",
    }
    audit_event(action="run_drift_detection", subject=principal.subject, identity=slug,
                correlation_id=cid)
    return {"identity": slug, "drift": _drift_results[slug], "correlation_id": cid}


@app.post("/api/v1/states/{provider}/{customer}/{environment}/{component}/drift-report")
async def report_drift(
    provider: str,
    customer: str,
    environment: str,
    component: str,
    body: dict,
    principal: Principal = Depends(require_role(ROLE_PRIVILEGED)),
):
    """Pipeline reports drift results here (privileged, typically the CI SA)."""
    slug = f"{provider}/{customer}/{environment}/{component}"
    if not registry.resolve(slug):
        raise HTTPException(404, "state not registered")
    cid = new_correlation_id()
    detected = bool(body.get("drift_detected"))
    _drift_results[slug] = {
        "status": "completed",
        "drift_detected": detected,
        "summary": str(body.get("summary", ""))[:512],
        "reported_by": principal.subject,
        "reported_at": _iso(datetime.now(timezone.utc)),
        "pipeline_run_id": body.get("pipeline_run_id"),
    }
    ref, _, _ = registry.resolve(slug)
    metrics.drift_detected.labels(**metrics.labels_for(ref.identity)).set(1 if detected else 0)
    audit_event(action="drift_report", subject=principal.subject, identity=slug,
                correlation_id=cid, detail={"drift_detected": detected})
    return {"ok": True, "correlation_id": cid}


@app.post("/api/v1/states/{provider}/{customer}/{environment}/{component}/backup")
async def backup_state(
    provider: str,
    customer: str,
    environment: str,
    component: str,
    principal: Principal = Depends(require_role(ROLE_OPERATOR)),
):
    """Server-side-encrypted backup of current state into the same backend
    under backups/ prefix. Never leaves the backend; never returned to caller."""
    slug = f"{provider}/{customer}/{environment}/{component}"
    resolved = registry.resolve(slug)
    if not resolved:
        raise HTTPException(404, "state not registered")
    ref, adapter, _ = resolved
    cid = new_correlation_id()
    try:
        result = await adapter.backup(ref)
        audit_event(action="backup_state", subject=principal.subject, identity=slug,
                    correlation_id=cid, detail={"backup_key": result["backup_key"]})
        return {"identity": slug, "backup": result, "correlation_id": cid}
    except Exception as e:  # noqa: BLE001
        audit_event(action="backup_state", subject=principal.subject, identity=slug,
                    outcome="error", correlation_id=cid,
                    detail={"error": type(e).__name__})
        raise HTTPException(502, f"backup failed: {type(e).__name__}")


@app.post("/api/v1/states/{provider}/{customer}/{environment}/{component}/migrate")
async def initiate_migration(
    provider: str,
    customer: str,
    environment: str,
    component: str,
    body: dict,
    principal: Principal = Depends(require_role(ROLE_PRIVILEGED)),
):
    """Create a migration APPROVAL REQUEST. This service never executes
    migrations. The request is audited and handed to the pipeline system
    (webhook or polled), where a human approval gate triggers the actual
    migration orchestrator (scripts/migration-orchestrator.sh)."""
    slug = f"{provider}/{customer}/{environment}/{component}"
    if not registry.resolve(slug):
        raise HTTPException(404, "state not registered")
    target = body.get("target", {})
    if not target.get("provider") or not target.get("component"):
        raise HTTPException(422, "target.provider and target.component required")
    cid = new_correlation_id()
    request_id = f"mig-{cid}"
    _migration_requests[request_id] = {
        "request_id": request_id,
        "source": slug,
        "target": target,
        "requested_by": principal.subject,
        "requested_at": _iso(datetime.now(timezone.utc)),
        "status": "pending_approval",
        "approval_required": True,
    }
    audit_event(action="initiate_migration", subject=principal.subject, identity=slug,
                correlation_id=cid,
                detail={"request_id": request_id, "target": target})
    return {"migration_request": _migration_requests[request_id], "correlation_id": cid}


@app.get("/api/v1/migrations")
async def list_migrations(principal: Principal = Depends(get_principal)):
    return {"migrations": list(_migration_requests.values())}


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------
async def _get_status_summary(slug: str) -> dict:
    cached = _status_cache.get(slug)
    if cached and time.time() - cached[0] < STATUS_TTL:
        return cached[1]
    resolved = registry.resolve(slug)
    if not resolved:
        return {}
    ref, adapter, _ = resolved
    status = await adapter.status(ref)
    lock = await adapter.lock_info(ref)
    summary = {
        "backend_type": ref.backend_type,
        "reachable": status.reachable,
        "exists": status.exists,
        "locked": lock.locked,
        "last_modified": _iso(status.last_modified),
    }
    _status_cache[slug] = (time.time(), summary)
    lbl = metrics.labels_for(ref.identity)
    metrics.backend_reachable.labels(**lbl).set(1 if status.reachable else 0)
    metrics.locked.labels(**lbl).set(1 if lock.locked else 0)
    if status.last_modified:
        metrics.last_operation_ts.labels(**lbl).set(status.last_modified.timestamp())
    return summary


def _health_of(summary: dict) -> str:
    if not summary:
        return "unknown"
    if not summary.get("reachable"):
        return "unreachable"
    if summary.get("locked"):
        return "locked"
    if summary.get("exists"):
        return "healthy"
    return "missing"


async def _metrics_refresher():
    """Background loop: refresh reachability/lock gauges for all states."""
    interval = int(os.getenv("METRICS_REFRESH_INTERVAL", "60"))
    while True:
        try:
            for ident in registry.list_identities():
                try:
                    await _get_status_summary(ident.slug)
                except Exception:  # noqa: BLE001
                    log.debug("status refresh failed for %s", ident.slug)
        except Exception:  # noqa: BLE001
            log.exception("metrics refresh cycle failed")
        await asyncio.sleep(interval)


def _iso(dt) -> str | None:
    if dt is None:
        return None
    if isinstance(dt, str):
        return dt
    return dt.astimezone(timezone.utc).isoformat()
