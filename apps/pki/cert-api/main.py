"""
Cert-API: Cryptographic Inventory REST API Service
Phase 12 — Full Certificate Lifecycle

Provides CRUD operations for certificate inventory with lifecycle management.
"""

import os
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timedelta
from typing import List, Optional

import structlog
from fastapi import FastAPI, HTTPException, Query, Depends, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from sqlalchemy import create_engine, text, func
from sqlalchemy.orm import sessionmaker, Session

from models import (
    CertificateRecord,
    CertificateQuery,
    CertificateQueryResult,
    CertificateStats,
    HealthCheck,
    DiscoverySource,
    CertificateStatus,
    PQCReadiness,
    KeyAlgorithm,
    SignatureAlgorithm,
)

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

# Metrics
REQUEST_COUNT = Counter(
    "cert_api_requests_total",
    "Total requests",
    ["method", "endpoint", "status"]
)
REQUEST_DURATION = Histogram(
    "cert_api_request_duration_seconds",
    "Request duration",
    ["method", "endpoint"]
)

# Database configuration
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://certapi:certinventory-password-change-me@pki-database:5432/certinventory"
)

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# FastAPI app
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    logger.info("cert_api.starting", version="0.2.0")
    yield
    logger.info("cert_api.stopping")

app = FastAPI(
    title="Cryptographic Inventory API",
    description="Certificate and cryptographic asset inventory service with lifecycle management",
    version="0.2.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Dependency
async def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Health check
@app.get("/health", response_model=HealthCheck)
async def health_check():
    """Service health check."""
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return HealthCheck(
            status="healthy",
            version="0.2.0",
            database_connected=True,
            discovery_sources=["ejbca", "openbao_pki", "kubernetes_secret"]
        )
    except Exception as e:
        logger.error("health_check.failed", error=str(e))
        raise HTTPException(status_code=503, detail="Database unavailable")

# Metrics endpoint
@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint."""
    from starlette.responses import Response
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

# Certificate CRUD
@app.post("/api/v1/certificates", response_model=CertificateRecord)
async def create_certificate(
    cert: CertificateRecord,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """Create a new certificate record."""
    logger.info("certificate.create", serial=cert.serial_number, hostname=cert.hostname)
    
    # Calculate days remaining
    if cert.not_after:
        cert.days_remaining = (cert.not_after - datetime.utcnow()).days
    
    # Determine status
    if cert.days_remaining is not None:
        if cert.days_remaining < 0:
            cert.status = CertificateStatus.EXPIRED
        else:
            cert.status = CertificateStatus.ACTIVE
    
    # Store in database
    # TODO: Implement actual database insert
    
    return cert

@app.get("/api/v1/certificates", response_model=CertificateQueryResult)
async def list_certificates(
    hostname: Optional[str] = None,
    application: Optional[str] = None,
    environment: Optional[str] = None,
    status: Optional[CertificateStatus] = None,
    source_ca: Optional[DiscoverySource] = None,
    expires_before_days: Optional[int] = None,
    limit: int = Query(100, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db)
):
    """List certificates with filtering."""
    logger.info("certificate.list", filters={
        "hostname": hostname,
        "status": status,
        "source_ca": source_ca
    })
    
    # TODO: Implement actual database query
    return CertificateQueryResult(
        total=0,
        certificates=[],
        limit=limit,
        offset=offset
    )

@app.get("/api/v1/certificates/expiring")
async def get_expiring_certificates(
    days: int = Query(30, ge=1, le=365),
    db: Session = Depends(get_db)
):
    """Get certificates expiring within specified days."""
    logger.info("certificate.expiring", days=days)
    
    try:
        with engine.connect() as conn:
            result = conn.execute(text("""
                SELECT * FROM certificates
                WHERE status = 'active'
                  AND not_after <= CURRENT_TIMESTAMP + INTERVAL ':days days'
                ORDER BY not_after ASC
            """), {"days": days})
            
            certificates = []
            for row in result.mappings():
                cert_dict = dict(row)
                cert_dict["subject_alternative_names"] = cert_dict.get("subject_alternative_names", []) or []
                cert_dict["metadata"] = cert_dict.get("metadata", {}) or {}
                certificates.append(cert_dict)
            
            return {"certificates": certificates, "count": len(certificates)}
    except Exception as e:
        logger.error("certificate.expiring.failed", error=str(e))
        return {"certificates": [], "count": 0}

@app.post("/api/v1/certificates/{serial_number}/renew")
async def renew_certificate(
    serial_number: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """Renew a certificate by serial number."""
    logger.info("certificate.renew", serial=serial_number)
    
    # TODO: Implement actual renewal logic
    # 1. Look up certificate in database
    # 2. Request new certificate from CA
    # 3. Update database record
    # 4. Log audit event
    
    return {"status": "renewed", "serial_number": serial_number}

@app.post("/api/v1/certificates/{serial_number}/revoke")
async def revoke_certificate(
    serial_number: str,
    reason: str = "unspecified",
    db: Session = Depends(get_db)
):
    """Revoke a certificate by serial number."""
    logger.info("certificate.revoke", serial=serial_number, reason=reason)
    
    # TODO: Implement actual revocation logic
    # 1. Look up certificate in database
    # 2. Send revocation request to CA
    # 3. Update database record
    # 4. Log audit event
    
    return {"status": "revoked", "serial_number": serial_number, "reason": reason}

@app.get("/api/v1/certificates/{serial_number}")
async def get_certificate(
    serial_number: str,
    db: Session = Depends(get_db)
):
    """Get a single certificate by serial number."""
    logger.info("certificate.get", serial=serial_number)
    
    # TODO: Implement actual database query
    raise HTTPException(status_code=404, detail="Certificate not found")

@app.delete("/api/v1/certificates/{serial_number}")
async def delete_certificate(
    serial_number: str,
    db: Session = Depends(get_db)
):
    """Delete a certificate record (does not revoke)."""
    logger.info("certificate.delete", serial=serial_number)
    
    # TODO: Implement actual deletion
    return {"status": "deleted", "serial_number": serial_number}

# Statistics
@app.get("/api/v1/stats", response_model=CertificateStats)
async def get_statistics(db: Session = Depends(get_db)):
    """Get certificate inventory statistics."""
    logger.info("stats.get")
    
    try:
        with engine.connect() as conn:
            total = conn.execute(text("SELECT COUNT(*) FROM certificates")).scalar() or 0
            active = conn.execute(text("SELECT COUNT(*) FROM certificates WHERE status = 'active'")).scalar() or 0
            expired = conn.execute(text("SELECT COUNT(*) FROM certificates WHERE status = 'expired'")).scalar() or 0
            revoked = conn.execute(text("SELECT COUNT(*) FROM certificates WHERE status = 'revoked'")).scalar() or 0
            expiring_30 = conn.execute(text("SELECT COUNT(*) FROM v_certificates_expiring_30_days")).scalar() or 0
            
            return CertificateStats(
                total_certificates=total,
                active_certificates=active,
                expired_certificates=expired,
                revoked_certificates=revoked,
                expiring_30_days=expiring_30,
                expiring_7_days=0,
                expiring_1_day=0,
                pqc_ready=0,
                pqc_vulnerable=0,
                by_source={},
                by_environment={}
            )
    except Exception as e:
        logger.error("stats.failed", error=str(e))
        return CertificateStats(
            total_certificates=0,
            active_certificates=0,
            expired_certificates=0,
            revoked_certificates=0,
            expiring_30_days=0,
            expiring_7_days=0,
            expiring_1_day=0,
            pqc_ready=0,
            pqc_vulnerable=0,
            by_source={},
            by_environment={}
        )

# Discovery jobs
@app.post("/api/v1/discovery/trigger")
async def trigger_discovery(
    source: Optional[DiscoverySource] = None,
    db: Session = Depends(get_db)
):
    """Trigger a certificate discovery job."""
    logger.info("discovery.trigger", source=source)
    
    # TODO: Implement actual discovery trigger
    return {"status": "triggered", "source": source, "job_id": str(uuid.uuid4())}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
