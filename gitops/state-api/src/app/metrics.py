"""Prometheus metrics — safe, metadata-only series.

Exposed series (per state identity, label-carded):
  state_backend_reachable{provider,customer,environment,component} 0/1
  state_locked{...} 0/1
  state_version{...} serial number (gauge)
  state_resource_count{...} managed resource count
  state_drift_detected{...} 0/1 (set by drift detection runs)
  state_last_operation_timestamp{...} unix seconds of last terraform op
"""
from __future__ import annotations

from prometheus_client import CollectorRegistry, Gauge, generate_latest

registry = CollectorRegistry()

_LABELS = ["provider", "customer", "environment", "component"]

backend_reachable = Gauge("state_backend_reachable", "Backend reachable", _LABELS, registry=registry)
locked = Gauge("state_locked", "State lock held", _LABELS, registry=registry)
version = Gauge("state_version", "State serial", _LABELS, registry=registry)
resource_count = Gauge("state_resource_count", "Managed resources in state", _LABELS, registry=registry)
drift_detected = Gauge("state_drift_detected", "Drift detected on last check", _LABELS, registry=registry)
last_operation_ts = Gauge(
    "state_last_operation_timestamp", "Last terraform operation (unix seconds)", _LABELS, registry=registry
)


def labels_for(identity) -> dict:
    return {
        "provider": identity.provider,
        "customer": identity.customer,
        "environment": identity.environment,
        "component": identity.component,
    }


def render() -> bytes:
    return generate_latest(registry)
