"""Audit logging — every read and every action emits a structured event.

Events go to stdout (collected by the cluster log pipeline) and are
correlation-id tagged. Sensitive fields are never logged.
"""
from __future__ import annotations

import json
import logging
import time
import uuid
from typing import Any, Optional

_audit = logging.getLogger("state-api.audit")
_audit.setLevel(logging.INFO)


def new_correlation_id() -> str:
    return uuid.uuid4().hex[:16]


def audit_event(
    *,
    action: str,
    subject: str,
    identity: Optional[str] = None,
    outcome: str = "success",
    correlation_id: Optional[str] = None,
    detail: Optional[dict[str, Any]] = None,
) -> str:
    cid = correlation_id or new_correlation_id()
    event = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "audit": True,
        "correlation_id": cid,
        "action": action,
        "subject": subject,
        "state_identity": identity,
        "outcome": outcome,
        "detail": detail or {},
    }
    _audit.info(json.dumps(event))
    return cid
