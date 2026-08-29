"""
CA Service API
Phase 6 — Multi-CA Abstraction Layer

REST API for certificate operations across multiple CA providers.
"""

import os
from contextlib import asynccontextmanager
from typing import List, Optional, Dict, Any

import structlog
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware

from app.models import (
    CAProvider,
    CAOperation,
    CAProviderCapabilities,
    CertificateRequest,
    CertificateResponse,
    RevocationRequest,
    RevocationResponse,
    CAStatus,
    CAChainResponse,
    ProviderConfig,
    CapabilityCheck,
)
from certificate_service import CertificateService, ProviderSelectionStrategy

# Configure logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer(),
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

# Initialize service
cert_service = CertificateService()

# Load providers from environment/config
# In production, this would come from a config file or Kubernetes ConfigMap
DEFAULT_PROVIDERS = [
    ProviderConfig(
        provider=CAProvider.EJBCA,
        name="ejbca-primary",
        enabled=True,
        priority=10,
        base_url=os.getenv("EJBCA_URL", "https://ejbca-ejbca-ce:8443/ejbca"),
        auth_type="userpass",
        credentials={
            "username": os.getenv("EJBCA_USERNAME", ""),
            "password": os.getenv("EJBCA_PASSWORD", ""),
            "ca_name": os.getenv("EJBCA_CA_NAME", "ManagementCA"),
        },
        default_certificate_profile="TLS Server",
        default_validity_days=365,
    ),
    ProviderConfig(
        provider=CAProvider.OPENBAO_PKI,
        name="openbao-pki",
        enabled=True,
        priority=20,
        base_url=os.getenv("OPENBAO_URL", "https://openbao:8200"),
        auth_type="token",
        credentials={
            "token": os.getenv("OPENBAO_TOKEN", ""),
            "mount_path": os.getenv("OPENBAO_MOUNT_PATH", "pki"),
            "default_role": os.getenv("OPENBAO_DEFAULT_ROLE", "default"),
        },
        default_validity_days=30,
        max_validity_days=90,
    ),
]

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    logger.info("ca_service.starting", version="0.1.0")
    
    # Register default providers
    for config in DEFAULT_PROVIDERS:
        if config.enabled and config.credentials.get("username") or config.credentials.get("token"):
            try:
                cert_service.register_provider(config)
                logger.info("provider_registered", provider=config.name, type=config.provider.value)
            except Exception as e:
                logger.error("provider_registration_failed", provider=config.name, error=str(e))
    
    yield
    
    logger.info("ca_service.stopping")

app = FastAPI(
    title="CA Service API",
    description="Multi-CA abstraction layer for certificate operations",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    providers = cert_service.list_providers()
    status = cert_service.get_status()
    
    healthy_count = sum(1 for s in status.values() if s.healthy)
    
    return {
        "status": "healthy" if healthy_count > 0 else "degraded",
        "version": "0.1.0",
        "providers_total": len(providers),
        "providers_healthy": healthy_count,
        "providers": providers,
    }


@app.get("/providers", response_model=Dict[str, CAProviderCapabilities])
async def list_providers():
    """List all registered providers and their capabilities."""
    return cert_service.get_all_capabilities()


@app.get("/providers/{provider_name}/capabilities", response_model=CAProviderCapabilities)
async def get_provider_capabilities(provider_name: str):
    """Get capabilities of a specific provider."""
    try:
        return cert_service.get_provider_capabilities(provider_name)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@app.get("/providers/{provider_name}/status", response_model=CAStatus)
async def get_provider_status(provider_name: str):
    """Get status of a specific provider."""
    status = cert_service.get_status(provider_name)
    if not status:
        raise HTTPException(status_code=404, detail="Provider not found")
    return status.get(provider_name)


@app.post("/providers/{provider_name}/check/{operation}", response_model=CapabilityCheck)
async def check_capability(provider_name: str, operation: CAOperation):
    """Check if a provider supports a specific operation."""
    try:
        return cert_service.check_capability(provider_name, operation)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@app.post("/certificates/issue", response_model=CertificateResponse)
async def issue_certificate(
    request: CertificateRequest,
    provider: Optional[str] = None,
    strategy: Optional[ProviderSelectionStrategy] = ProviderSelectionStrategy.CAPABILITY,
):
    """Issue a new certificate."""
    try:
        return cert_service.issue_certificate(request, provider_name=provider, strategy=strategy)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error("certificate_issuance_failed", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/certificates/revoke", response_model=RevocationResponse)
async def revoke_certificate(
    request: RevocationRequest,
    provider: Optional[str] = None,
):
    """Revoke a certificate."""
    try:
        return cert_service.revoke_certificate(request, provider_name=provider)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error("certificate_revocation_failed", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/certificates/{serial_number}", response_model=CertificateResponse)
async def get_certificate(serial_number: str, provider: Optional[str] = None):
    """Get a certificate by serial number."""
    cert = cert_service.get_certificate(serial_number, provider_name=provider)
    if not cert:
        raise HTTPException(status_code=404, detail="Certificate not found")
    return cert


@app.get("/ca-chain", response_model=CAChainResponse)
async def get_ca_chain(provider: Optional[str] = None):
    """Get CA certificate chain."""
    try:
        return cert_service.get_ca_chain(provider_name=provider)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error("ca_chain_retrieval_failed", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/status")
async def get_all_status():
    """Get status of all providers."""
    return cert_service.get_status()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
