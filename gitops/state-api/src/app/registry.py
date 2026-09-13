"""State registry — resolves state identities to backend coordinates.

The registry is config-driven (ConfigMap), NOT user-supplied at request time.
This prevents callers from pointing the API at arbitrary backends/buckets.
Only pre-registered (provider, customer, environment, component) tuples are
addressable.
"""
from __future__ import annotations

import logging
import os
from pathlib import Path

import yaml

from .adapters import PROVIDER_BACKEND, build_adapter, StateBackendAdapter
from .models import StateIdentity, StateRef

log = logging.getLogger("state-api.registry")

CONFIG_PATH = os.getenv("STATE_REGISTRY_CONFIG", "/etc/state-api/registry.yaml")


class StateRegistry:
    def __init__(self, path: str = CONFIG_PATH):
        self._path = path
        self._entries: dict[str, dict] = {}
        self._adapters: dict[str, StateBackendAdapter] = {}
        self.reload()

    def reload(self) -> None:
        p = Path(self._path)
        if not p.exists():
            log.warning("registry config %s missing; running empty", self._path)
            self._entries = {}
            return
        data = yaml.safe_load(p.read_text()) or {}
        self._entries = {}
        self._adapters = {}
        for entry in data.get("states", []):
            ident = StateIdentity(
                provider=entry["provider"],
                customer=entry.get("customer", "default"),
                environment=entry["environment"],
                component=entry["component"],
            )
            backend_cfg = dict(entry.get("backend", {}))
            self._entries[ident.slug] = {
                "identity": ident,
                "backend_config": backend_cfg,
                "pipeline": entry.get("pipeline", {}),
            }
        log.info("registry loaded: %d state entries", len(self._entries))

    def list_identities(self) -> list[StateIdentity]:
        return [e["identity"] for e in self._entries.values()]

    def resolve(self, slug: str) -> tuple[StateRef, StateBackendAdapter, dict] | None:
        entry = self._entries.get(slug)
        if not entry:
            return None
        ident: StateIdentity = entry["identity"]
        backend_type = PROVIDER_BACKEND[ident.provider]
        ref = StateRef(
            identity=ident,
            backend_type=backend_type,
            state_key=ident.state_key,
            backend_config=entry["backend_config"],
        )
        if ident.provider not in self._adapters:
            self._adapters[ident.provider] = build_adapter(
                ident.provider, entry["backend_config"]
            )
        return ref, self._adapters[ident.provider], entry.get("pipeline", {})


registry = StateRegistry()
