"""Authentication & authorization.

Design:
- OIDC bearer tokens (platform SSO) when OIDC_ISSUER is configured.
- Kubernetes TokenReview fallback for in-cluster service-to-service calls.
- Roles (from token claim `groups` or `roles`):
    state-viewer     — read-only metadata, health, versions (DEFAULT)
    state-operator   — + validate, drift detection, backup
    state-privileged — + migrations, force-unlock requests (approval-gated)
- Read-only by default: no role ⇒ viewer-equivalent on non-sensitive fields.

NO endpoint in this service performs terraform state rm/push/force-unlock.
Privileged actions create an *approval request* (audit event + optional
webhook to the pipeline system); a human pipeline executes the change.
"""
from __future__ import annotations

import logging
import os
import time
from dataclasses import dataclass, field

import jwt
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

log = logging.getLogger("state-api.auth")

ROLE_VIEWER = "state-viewer"
ROLE_OPERATOR = "state-operator"
ROLE_PRIVILEGED = "state-privileged"

ROLE_RANK = {ROLE_VIEWER: 1, ROLE_OPERATOR: 2, ROLE_PRIVILEGED: 3}

_bearer = HTTPBearer(auto_error=False)

_oidc_issuer = os.getenv("OIDC_ISSUER", "")
_oidc_audience = os.getenv("OIDC_AUDIENCE", "state-api")
_jwks_cache: dict = {"keys": None, "fetched_at": 0}


@dataclass
class Principal:
    subject: str
    roles: set[str] = field(default_factory=lambda: {ROLE_VIEWER})
    auth_method: str = "none"

    def has_role(self, role: str) -> bool:
        return any(ROLE_RANK.get(r, 0) >= ROLE_RANK[role] for r in self.roles)


async def _fetch_jwks() -> dict:
    if _jwks_cache["keys"] and time.time() - _jwks_cache["fetched_at"] < 3600:
        return _jwks_cache["keys"]
    import httpx

    url = f"{_oidc_issuer.rstrip('/')}/.well-known/jwks.json"
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(url)
        resp.raise_for_status()
        _jwks_cache["keys"] = resp.json()
        _jwks_cache["fetched_at"] = time.time()
    return _jwks_cache["keys"]


async def _validate_oidc(token: str) -> Principal | None:
    try:
        jwks = await _fetch_jwks()
        header = jwt.get_unverified_header(token)
        key = next((k for k in jwks["keys"] if k["kid"] == header.get("kid")), None)
        if not key:
            return None
        claims = jwt.decode(
            token,
            key=jwt.algorithms.RSAAlgorithm.from_jwk(key),
            algorithms=["RS256"],
            audience=_oidc_audience,
            issuer=_oidc_issuer,
        )
        groups = set(claims.get("groups", []) or [])
        roles = {g for g in groups if g in ROLE_RANK} or {ROLE_VIEWER}
        return Principal(
            subject=claims.get("sub", "unknown"), roles=roles, auth_method="oidc"
        )
    except jwt.PyJWTError as e:
        log.info("OIDC validation failed: %s", type(e).__name__)
        return None


async def _validate_k8s_token(token: str, request: Request) -> Principal | None:
    """TokenReview against the in-cluster API (audience: state-api)."""
    import httpx

    sa_token_path = "/var/run/secrets/kubernetes.io/serviceaccount/token"
    if not os.path.exists(sa_token_path):
        return None
    with open(sa_token_path) as f:
        sa_token = f.read().strip()
    review = {
        "apiVersion": "authentication.k8s.io/v1",
        "kind": "TokenReview",
        "spec": {"token": token, "audiences": ["state-api"]},
    }
    try:
        async with httpx.AsyncClient(
            base_url="https://kubernetes.default.svc",
            headers={"Authorization": f"Bearer {sa_token}"},
            verify="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt",
            timeout=5,
        ) as client:
            resp = await client.post("/apis/authentication.k8s.io/v1/tokenreviews", json=review)
            data = resp.json()
        st = data.get("status", {})
        if not st.get("authenticated"):
            return None
        groups = set(st.get("user", {}).get("groups", []) or [])
        roles = {g for g in groups if g in ROLE_RANK} or {ROLE_VIEWER}
        return Principal(
            subject=st.get("user", {}).get("username", "unknown"),
            roles=roles,
            auth_method="k8s-tokenreview",
        )
    except Exception as e:  # noqa: BLE001
        log.warning("TokenReview failed: %s", type(e).__name__)
        return None


async def get_principal(
    request: Request,
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> Principal:
    if creds is None:
        # Auth required. No anonymous access to state metadata.
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = creds.credentials
    if _oidc_issuer:
        principal = await _validate_oidc(token)
        if principal:
            request.state.principal = principal
            return principal
    principal = await _validate_k8s_token(token, request)
    if principal:
        request.state.principal = principal
        return principal
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="invalid token",
        headers={"WWW-Authenticate": "Bearer"},
    )


def require_role(role: str):
    async def _checker(principal: Principal = Depends(get_principal)) -> Principal:
        if not principal.has_role(role):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"role {role} required",
            )
        return principal

    return _checker
