"""State identity model: provider/customer/environment/component.

This is the canonical addressing scheme for every Terraform state tracked by
the platform. It mirrors docs/architecture/state-architecture.md and the
migration-agent state namespace (e.g. azure/default/lab/core).
"""
from __future__ import annotations

import re
from dataclasses import dataclass

from pydantic import BaseModel, Field, field_validator

_NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,62}$")

PROVIDERS = ("azure", "aws", "alibaba")
COMPONENTS = ("core", "addons", "monitoring")
ENVIRONMENTS = ("lab", "dev", "staging", "prod")


class StateIdentity(BaseModel):
    """Fully-qualified state address."""

    provider: str = Field(..., description="Cloud provider: azure|aws|alibaba")
    customer: str = Field(default="default", description="Customer/tenant id")
    environment: str = Field(..., description="lab|dev|staging|prod")
    component: str = Field(..., description="core|addons|monitoring")

    @field_validator("provider")
    @classmethod
    def _provider_ok(cls, v: str) -> str:
        v = v.lower()
        if v not in PROVIDERS:
            raise ValueError(f"provider must be one of {PROVIDERS}")
        return v

    @field_validator("component")
    @classmethod
    def _component_ok(cls, v: str) -> str:
        v = v.lower()
        if v not in COMPONENTS:
            raise ValueError(f"component must be one of {COMPONENTS}")
        return v

    @field_validator("customer", "environment")
    @classmethod
    def _name_ok(cls, v: str) -> str:
        v = v.lower()
        if not _NAME_RE.match(v):
            raise ValueError("must be lowercase alphanumeric with dashes")
        return v

    @property
    def state_key(self) -> str:
        """Canonical backend state key/path."""
        return (
            f"customers/{self.customer}/{self.environment}/"
            f"{self.provider}/{self.component}/terraform.tfstate"
        )

    @property
    def slug(self) -> str:
        return f"{self.provider}/{self.customer}/{self.environment}/{self.component}"

    def __str__(self) -> str:  # pragma: no cover
        return self.slug


@dataclass(frozen=True)
class StateRef:
    """Resolved backend coordinates for a state identity."""

    identity: StateIdentity
    backend_type: str  # azurerm | s3 | oss
    state_key: str
    backend_config: dict  # bucket/container/account/etc — never credentials
