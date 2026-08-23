"""
Cryptographic Inventory Models
Shared data models for certificate inventory service.
"""

from datetime import datetime
from enum import Enum
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field


class CertificateStatus(str, Enum):
    ACTIVE = "active"
    EXPIRED = "expired"
    REVOKED = "revoked"
    PENDING = "pending"
    UNKNOWN = "unknown"


class KeyAlgorithm(str, Enum):
    RSA = "RSA"
    ECDSA = "ECDSA"
    ED25519 = "Ed25519"
    DSA = "DSA"
    UNKNOWN = "Unknown"


class SignatureAlgorithm(str, Enum):
    SHA256_WITH_RSA = "sha256WithRSAEncryption"
    SHA384_WITH_RSA = "sha384WithRSAEncryption"
    SHA512_WITH_RSA = "sha512WithRSAEncryption"
    ECDSA_WITH_SHA256 = "ecdsa-with-SHA256"
    ECDSA_WITH_SHA384 = "ecdsa-with-SHA384"
    ECDSA_WITH_SHA512 = "ecdsa-with-SHA512"
    ED25519 = "ed25519"
    SHA1_WITH_RSA = "sha1WithRSAEncryption"
    MD5_WITH_RSA = "md5WithRSAEncryption"
    UNKNOWN = "unknown"


class PQCReadiness(str, Enum):
    READY = "ready"           # Already using PQC algorithms
    MIGRATING = "migrating"   # In progress
    VULNERABLE = "vulnerable" # Uses algorithms vulnerable to quantum attacks
    UNKNOWN = "unknown"


class DiscoverySource(str, Enum):
    EJBCA = "ejbca"
    OPENBAO_PKI = "openbao_pki"
    SMALLSTEP = "smallstep"
    KUBERNETES_SECRET = "kubernetes_secret"
    TLS_SCAN = "tls_scan"
    MANUAL_IMPORT = "manual_import"
    CERT_MANAGER = "cert_manager"
    UNKNOWN = "unknown"


class CertificateRecord(BaseModel):
    """Core certificate inventory record."""
    
    # Identity
    id: Optional[str] = None
    hostname: Optional[str] = None
    application: Optional[str] = None
    service: Optional[str] = None
    environment: Optional[str] = None  # prod, staging, dev, etc.
    owner: Optional[str] = None  # team or individual responsible
    
    # Certificate Data
    certificate_subject: str
    subject_alternative_names: List[str] = Field(default_factory=list)
    serial_number: str
    issuer: str
    issuing_ca: Optional[str] = None
    
    # Cryptographic Properties
    key_algorithm: KeyAlgorithm = KeyAlgorithm.UNKNOWN
    key_size: Optional[int] = None
    signature_algorithm: SignatureAlgorithm = SignatureAlgorithm.UNKNOWN
    
    # Validity
    not_before: datetime
    not_after: datetime
    days_remaining: Optional[int] = None
    
    # Status
    status: CertificateStatus = CertificateStatus.UNKNOWN
    revocation_status: Optional[str] = None  # good, revoked, unknown
    revocation_date: Optional[datetime] = None
    revocation_reason: Optional[str] = None
    
    # Source & Discovery
    source_ca: DiscoverySource = DiscoverySource.UNKNOWN
    certificate_profile: Optional[str] = None
    discovery_method: Optional[str] = None
    last_seen: datetime = Field(default_factory=datetime.utcnow)
    
    # PQC & Future
    pqc_readiness: PQCReadiness = PQCReadiness.UNKNOWN
    crypto_policy_compliant: Optional[bool] = None
    
    # Raw Data (for debugging/auditing)
    pem_certificate: Optional[str] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)
    
    class Config:
        json_schema_extra = {
            "example": {
                "hostname": "api.homelab.local",
                "application": "cert-api",
                "service": "rest-api",
                "environment": "production",
                "owner": "platform-team",
                "certificate_subject": "CN=api.homelab.local,O=Homelab",
                "subject_alternative_names": ["api.homelab.local", "*.homelab.local"],
                "serial_number": "1234567890abcdef",
                "issuer": "CN=Homelab Intermediate CA,O=Homelab",
                "key_algorithm": "RSA",
                "key_size": 2048,
                "signature_algorithm": "sha256WithRSAEncryption",
                "not_before": "2024-01-01T00:00:00Z",
                "not_after": "2025-01-01T00:00:00Z",
                "source_ca": "ejbca",
                "certificate_profile": "TLS Server",
            }
        }


class CertificateQuery(BaseModel):
    """Query parameters for certificate search."""
    
    hostname: Optional[str] = None
    application: Optional[str] = None
    environment: Optional[str] = None
    owner: Optional[str] = None
    status: Optional[CertificateStatus] = None
    source_ca: Optional[DiscoverySource] = None
    certificate_profile: Optional[str] = None
    
    # Time-based filters
    expires_before_days: Optional[int] = None  # e.g., 30 for expiring in 30 days
    expires_after_days: Optional[int] = None
    not_seen_since_days: Optional[int] = None
    
    # Crypto policy filters
    key_algorithm: Optional[KeyAlgorithm] = None
    min_key_size: Optional[int] = None
    signature_algorithm: Optional[SignatureAlgorithm] = None
    pqc_readiness: Optional[PQCReadiness] = None
    crypto_policy_compliant: Optional[bool] = None
    
    # Pagination
    limit: int = Field(default=100, ge=1, le=1000)
    offset: int = Field(default=0, ge=0)


class CertificateQueryResult(BaseModel):
    """Result of certificate query."""
    total: int
    certificates: List[CertificateRecord]
    limit: int
    offset: int


class CertificateStats(BaseModel):
    """Statistics about certificate inventory."""
    total_certificates: int
    active_certificates: int
    expired_certificates: int
    revoked_certificates: int
    expiring_30_days: int
    expiring_7_days: int
    expiring_1_day: int
    pqc_ready: int
    pqc_vulnerable: int
    by_source: Dict[str, int]
    by_environment: Dict[str, int]


class DiscoveryJob(BaseModel):
    """Discovery job configuration."""
    id: Optional[str] = None
    name: str
    source: DiscoverySource
    enabled: bool = True
    schedule: str = "0 */6 * * *"  # Every 6 hours by default
    config: Dict[str, Any] = Field(default_factory=dict)
    last_run: Optional[datetime] = None
    last_status: Optional[str] = None
    last_error: Optional[str] = None


class HealthCheck(BaseModel):
    """Service health check response."""
    status: str
    version: str
    database_connected: bool
    last_discovery_run: Optional[datetime] = None
    discovery_sources: List[str]
