"""
Cert-API: Cryptographic Inventory REST API Service
Phase 5 — Cryptographic Inventory
"""

import os
from contextlib import asynccontextmanager
from datetime import datetime, timedelta
from typing import List, Optional

import structlog
from fastapi import FastAPI, HTTPException, Query, Depends
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from sqlalchemy import create_engine, text
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
    logger.info("cert_api.starting", version="0.1.0")
    yield
    logger.info("cert_api.stopping")

app = FastAPI(
    title="Cryptographic Inventory API",
    description="Certificate and cryptographic asset inventory service",
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

# Dependency
async def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@app.get("/health", response_model=HealthCheck)
async def health_check():
    """Health check endpoint."""
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
            db_connected = True
    except Exception as e:
        logger.error("health_check.database_failed", error=str(e))
        db_connected = False
    
    return HealthCheck(
        status="healthy" if db_connected else "degraded",
        version="0.1.0",
        database_connected=db_connected,
        discovery_sources=[
            DiscoverySource.EJBCA,
            DiscoverySource.OPENBAO_PKI,
            DiscoverySource.KUBERNETES_SECRET,
            DiscoverySource.TLS_SCAN,
            DiscoverySource.MANUAL_IMPORT,
        ],
    )


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint."""
    from starlette.responses import Response
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST,
    )


@app.get("/certificates", response_model=CertificateQueryResult)
async def list_certificates(
    hostname: Optional[str] = None,
    application: Optional[str] = None,
    environment: Optional[str] = None,
    owner: Optional[str] = None,
    status: Optional[CertificateStatus] = None,
    source_ca: Optional[DiscoverySource] = None,
    expires_before_days: Optional[int] = None,
    min_key_size: Optional[int] = None,
    key_algorithm: Optional[KeyAlgorithm] = None,
    pqc_readiness: Optional[PQCReadiness] = None,
    limit: int = Query(100, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    """Query certificates with filters."""
    query = db.query(CertificateRecord)
    
    if hostname:
        query = query.filter(CertificateRecord.hostname.ilike(f"%{hostname}%"))
    if application:
        query = query.filter(CertificateRecord.application == application)
    if environment:
        query = query.filter(CertificateRecord.environment == environment)
    if owner:
        query = query.filter(CertificateRecord.owner == owner)
    if status:
        query = query.filter(CertificateRecord.status == status)
    if source_ca:
        query = query.filter(CertificateRecord.source_ca == source_ca)
    if expires_before_days:
        cutoff = datetime.utcnow() + timedelta(days=expires_before_days)
        query = query.filter(CertificateRecord.not_after <= cutoff)
    if min_key_size:
        query = query.filter(CertificateRecord.key_size < min_key_size)
    if key_algorithm:
        query = query.filter(CertificateRecord.key_algorithm == key_algorithm)
    if pqc_readiness:
        query = query.filter(CertificateRecord.pqc_readiness == pqc_readiness)
    
    total = query.count()
    certificates = query.offset(offset).limit(limit).all()
    
    return CertificateQueryResult(
        total=total,
        certificates=certificates,
        limit=limit,
        offset=offset,
    )


@app.get("/certificates/{certificate_id}", response_model=CertificateRecord)
async def get_certificate(certificate_id: str, db: Session = Depends(get_db)):
    """Get a specific certificate by ID."""
    cert = db.query(CertificateRecord).filter(CertificateRecord.id == certificate_id).first()
    if not cert:
        raise HTTPException(status_code=404, detail="Certificate not found")
    return cert


@app.get("/certificates/serial/{serial_number}", response_model=CertificateRecord)
async def get_certificate_by_serial(serial_number: str, db: Session = Depends(get_db)):
    """Get a certificate by serial number."""
    cert = db.query(CertificateRecord).filter(
        CertificateRecord.serial_number == serial_number
    ).first()
    if not cert:
        raise HTTPException(status_code=404, detail="Certificate not found")
    return cert


@app.get("/stats", response_model=CertificateStats)
async def get_stats(db: Session = Depends(get_db)):
    """Get certificate inventory statistics."""
    from sqlalchemy import func
    
    total = db.query(CertificateRecord).count()
    active = db.query(CertificateRecord).filter(
        CertificateRecord.status == CertificateStatus.ACTIVE
    ).count()
    expired = db.query(CertificateRecord).filter(
        CertificateRecord.status == CertificateStatus.EXPIRED
    ).count()
    revoked = db.query(CertificateRecord).filter(
        CertificateRecord.status == CertificateStatus.REVOKED
    ).count()
    
    now = datetime.utcnow()
    expiring_30 = db.query(CertificateRecord).filter(
        CertificateRecord.status == CertificateStatus.ACTIVE,
        CertificateRecord.not_after <= now + timedelta(days=30)
    ).count()
    expiring_7 = db.query(CertificateRecord).filter(
        CertificateRecord.status == CertificateStatus.ACTIVE,
        CertificateRecord.not_after <= now + timedelta(days=7)
    ).count()
    expiring_1 = db.query(CertificateRecord).filter(
        CertificateRecord.status == CertificateStatus.ACTIVE,
        CertificateRecord.not_after <= now + timedelta(days=1)
    ).count()
    
    pqc_ready = db.query(CertificateRecord).filter(
        CertificateRecord.pqc_readiness == PQCReadiness.READY
    ).count()
    pqc_vulnerable = db.query(CertificateRecord).filter(
        CertificateRecord.pqc_readiness == PQCReadiness.VULNERABLE
    ).count()
    
    # Group by source
    by_source = {}
    for source in db.query(CertificateRecord.source_ca).distinct():
        count = db.query(CertificateRecord).filter(
            CertificateRecord.source_ca == source[0]
        ).count()
        by_source[source[0]] = count
    
    # Group by environment
    by_environment = {}
    for env in db.query(CertificateRecord.environment).distinct():
        count = db.query(CertificateRecord).filter(
            CertificateRecord.environment == env[0]
        ).count()
        by_environment[env[0]] = count
    
    return CertificateStats(
        total_certificates=total,
        active_certificates=active,
        expired_certificates=expired,
        revoked_certificates=revoked,
        expiring_30_days=expiring_30,
        expiring_7_days=expiring_7,
        expiring_1_day=expiring_1,
        pqc_ready=pqc_ready,
        pqc_vulnerable=pqc_vulnerable,
        by_source=by_source,
        by_environment=by_environment,
    )


@app.get("/queries/expiring-soon")
async def get_expiring_soon(
    days: int = Query(30, ge=1, le=365),
    environment: Optional[str] = None,
    db: Session = Depends(get_db),
):
    """Get certificates expiring within specified days."""
    cutoff = datetime.utcnow() + timedelta(days=days)
    query = db.query(CertificateRecord).filter(
        CertificateRecord.status == CertificateStatus.ACTIVE,
        CertificateRecord.not_after <= cutoff
    )
    
    if environment:
        query = query.filter(CertificateRecord.environment == environment)
    
    certificates = query.order_by(CertificateRecord.not_after.asc()).all()
    
    return {
        "days": days,
        "environment": environment,
        "count": len(certificates),
        "certificates": certificates,
    }


@app.get("/queries/weak-keys")
async def get_weak_keys(
    min_rsa_size: int = Query(2048, ge=512),
    db: Session = Depends(get_db),
):
    """Get certificates with weak key sizes."""
    certificates = db.query(CertificateRecord).filter(
        CertificateRecord.key_algorithm == KeyAlgorithm.RSA,
        CertificateRecord.key_size < min_rsa_size
    ).all()
    
    return {
        "min_rsa_size": min_rsa_size,
        "count": len(certificates),
        "certificates": certificates,
    }


@app.get("/queries/deprecated-algorithms")
async def get_deprecated_algorithms(db: Session = Depends(get_db)):
    """Get certificates using deprecated signature algorithms."""
    deprecated = [
        SignatureAlgorithm.SHA1_WITH_RSA,
        SignatureAlgorithm.MD5_WITH_RSA,
    ]
    
    certificates = db.query(CertificateRecord).filter(
        CertificateRecord.signature_algorithm.in_(deprecated)
    ).all()
    
    return {
        "deprecated_algorithms": [alg.value for alg in deprecated],
        "count": len(certificates),
        "certificates": certificates,
    }


@app.get("/queries/unknown-owners")
async def get_unknown_owners(db: Session = Depends(get_db)):
    """Get certificates with unknown or missing owners."""
    certificates = db.query(CertificateRecord).filter(
        (CertificateRecord.owner == None) | (CertificateRecord.owner == "")
    ).all()
    
    return {
        "count": len(certificates),
        "certificates": certificates,
    }


@app.get("/queries/stale")
async def get_stale_certificates(
    days: int = Query(7, ge=1),
    db: Session = Depends(get_db),
):
    """Get certificates not observed recently."""
    cutoff = datetime.utcnow() - timedelta(days=days)
    certificates = db.query(CertificateRecord).filter(
        CertificateRecord.status == CertificateStatus.ACTIVE,
        CertificateRecord.last_seen < cutoff
    ).all()
    
    return {
        "days": days,
        "count": len(certificates),
        "certificates": certificates,
    }


@app.get("/queries/pqc-vulnerable")
async def get_pqc_vulnerable(db: Session = Depends(get_db)):
    """Get certificates vulnerable to quantum computing attacks."""
    from sqlalchemy import or_
    
    certificates = db.query(CertificateRecord).filter(
        CertificateRecord.status == CertificateStatus.ACTIVE,
        or_(
            (CertificateRecord.key_algorithm == KeyAlgorithm.RSA) & (CertificateRecord.key_size < 3072),
            CertificateRecord.key_algorithm == KeyAlgorithm.DSA,
            (CertificateRecord.key_algorithm == KeyAlgorithm.ECDSA) & (CertificateRecord.key_size < 384),
        )
    ).all()
    
    return {
        "count": len(certificates),
        "certificates": certificates,
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
