"""Sanitization layer — the single most security-critical module in state-api.

RULE: Raw Terraform state NEVER leaves this service. Every response passes
through these functions which strip/redact anything that could contain a
secret: outputs, resource attributes, variables, backend credentials.

Deny-by-default: we build metadata from an allowlist of fields, not by
filtering a raw state dump.
"""
from __future__ import annotations

import hashlib
import re
from typing import Any

# Patterns that indicate a value is (or may be) sensitive. Applied to KEYS.
SENSITIVE_KEY_RE = re.compile(
    r"(password|passwd|secret|token|private[_-]?key|client[_-]?secret|"
    r"connection[_-]?string|credential|api[_-]?key|access[_-]?key|"
    r"cert(ificate)?[_-]?(pem|key|p12|pfx)|ssh[_-]?key|session|cookie)",
    re.IGNORECASE,
)

# Patterns that indicate a VALUE looks like a secret even if the key is benign.
SENSITIVE_VALUE_RE = re.compile(
    r"(-----BEGIN [A-Z ]*PRIVATE KEY-----|"
    r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|"  # JWT
    r"(password|secret|token)\s*[:=]\s*\S+)",
    re.IGNORECASE,
)

REDACTED = "***REDACTED***"


def fingerprint(value: str) -> str:
    """Stable non-reversible fingerprint for correlation without disclosure."""
    return hashlib.sha256(value.encode()).hexdigest()[:12]


def sanitize_value(key: str, value: Any) -> Any:
    """Return a safe representation of a single value."""
    if value is None:
        return None
    if SENSITIVE_KEY_RE.search(key):
        return REDACTED
    if isinstance(value, str):
        if SENSITIVE_VALUE_RE.search(value):
            return REDACTED
        # Truncate long free-form strings (could embed secrets)
        return value if len(value) <= 256 else value[:256] + "…"
    if isinstance(value, dict):
        return {k: sanitize_value(k, v) for k, v in value.items()}
    if isinstance(value, list):
        return [sanitize_value(key, v) for v in value[:50]]  # cap list size
    return value


def sanitize_outputs(raw_outputs: dict) -> dict:
    """Build the sanitized output summary shown in the UI.

    We never return output VALUES wholesale. Sensitive outputs are redacted;
    non-sensitive outputs are returned (they are part of the module contract,
    e.g. vpc_id, fqdn) but still pass value-pattern screening.
    """
    safe: dict[str, Any] = {}
    for name, out in (raw_outputs or {}).items():
        sensitive = bool(out.get("sensitive")) or bool(SENSITIVE_KEY_RE.search(name))
        if sensitive:
            safe[name] = {"sensitive": True, "value": REDACTED}
        else:
            v = out.get("value")
            safe[name] = {
                "sensitive": False,
                "value": sanitize_value(name, v),
            }
    return safe


def summarize_resources(raw_resources: list) -> dict:
    """Aggregate resource inventory WITHOUT exposing attributes.

    Returns counts by provider prefix and type, plus mode totals. Resource
    instance names/addresses are counted, not listed (addresses can embed
    customer naming but are needed for drift triage — we expose count only
    at this layer; the privileged metadata endpoint can list addresses).
    """
    by_type: dict[str, int] = {}
    managed = 0
    data = 0
    for res in raw_resources or []:
        mode = res.get("mode", "managed")
        rtype = res.get("type", "unknown")
        if mode == "data":
            data += 1
        else:
            managed += 1
        by_type[rtype] = by_type.get(rtype, 0) + 1
    return {
        "managed_count": managed,
        "data_count": data,
        "total_count": managed + data,
        "by_type": dict(sorted(by_type.items(), key=lambda kv: -kv[1])[:50]),
    }


def state_metadata_from_raw(raw: dict, identity_slug: str) -> dict:
    """Extract allowlisted metadata from a pulled state file.

    Allowlist: version, terraform_version, serial, lineage. Everything else
    is aggregated (resources) or sanitized (outputs). Raw state is discarded
    by the caller immediately after this function returns.
    """
    return {
        "identity": identity_slug,
        "version": raw.get("version"),
        "terraform_version": raw.get("terraform_version"),
        "serial": raw.get("serial"),
        "lineage": raw.get("lineage"),
        "resources": summarize_resources(raw.get("resources", [])),
        "outputs": sanitize_outputs(raw.get("outputs", {})),
    }
