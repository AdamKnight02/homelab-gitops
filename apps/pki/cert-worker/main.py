"""
Cert-Worker: Certificate Discovery Service
Phase 5 — Cryptographic Inventory

Discovers certificates from multiple sources:
- EJBCA
- OpenBao PKI
- Kubernetes Secrets
- TLS endpoint scanning
- Manual imports
"""

import os
import sys
import time
import base64
import ssl
import socket
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional

import httpx
import structlog
import schedule
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, Session

# Add shared models to path
sys.path.insert(0, '/app/shared')
from models import (
    CertificateRecord,
    DiscoverySource,
    CertificateStatus,
    KeyAlgorithm,
    SignatureAlgorithm,
    PQCReadiness,
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

# Database configuration
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://certapi:certinventory-password-change-me@pki-database:5432/certinventory"
)

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Source configurations
EJBCA_URL = os.getenv("EJBCA_URL", "https://ejbca-ejbca-ce:8443/ejbca")
EJBCA_USERNAME = os.getenv("EJBCA_USERNAME", "")
EJBCA_PASSWORD = os.getenv("EJBCA_PASSWORD", "")

OPENBAO_URL = os.getenv("OPENBAO_URL", "https://openbao:8200")
OPENBAO_TOKEN = os.getenv("OPENBAO_TOKEN", "")

KUBERNETES_API_URL = os.getenv("KUBERNETES_API_URL", "https://kubernetes.default.svc")


class CertificateDiscovery:
    """Base class for certificate discovery sources."""
    
    def __init__(self, source: DiscoverySource):
        self.source = source
        self.logger = logger.bind(source=source.value)
    
    def discover(self) -> List[CertificateRecord]:
        """Discover certificates from this source."""
        raise NotImplementedError
    
    def _parse_certificate(self, pem_data: str, **kwargs) -> Optional[CertificateRecord]:
        """Parse a PEM certificate and extract inventory fields."""
        try:
            cert = x509.load_pem_x509_certificate(pem_data.encode())
            
            # Extract subject
            subject = cert.subject.rfc4514_string()
            
            # Extract SANs
            sans = []
            try:
                ext = cert.extensions.get_extension_for_oid(
                    x509.oid.ExtensionOID.SUBJECT_ALTERNATIVE_NAME
                )
                for name in ext.value:
                    if isinstance(name, x509.DNSName):
                        sans.append(name.value)
                    elif isinstance(name, x509.IPAddress):
                        sans.append(str(name.value))
            except x509.ExtensionNotFound:
                pass
            
            # Extract key algorithm and size
            public_key = cert.public_key()
            key_alg = KeyAlgorithm.UNKNOWN
            key_size = None
            
            if hasattr(public_key, 'key_size'):
                key_size = public_key.key_size
            
            if isinstance(public_key, x509.RSAPublicKey):
                key_alg = KeyAlgorithm.RSA
            elif isinstance(public_key, x509.EllipticCurvePublicKey):
                key_alg = KeyAlgorithm.ECDSA
            elif hasattr(public_key, 'curve') and public_key.curve.name == 'Ed25519':
                key_alg = KeyAlgorithm.ED25519
            
            # Determine signature algorithm
            sig_alg = SignatureAlgorithm.UNKNOWN
            sig_alg_name = cert.signature_algorithm_oid._name if hasattr(cert.signature_algorithm_oid, '_name') else str(cert.signature_algorithm_oid)
            
            if 'sha256' in sig_alg_name.lower() and 'rsa' in sig_alg_name.lower():
                sig_alg = SignatureAlgorithm.SHA256_WITH_RSA
            elif 'sha384' in sig_alg_name.lower() and 'rsa' in sig_alg_name.lower():
                sig_alg = SignatureAlgorithm.SHA384_WITH_RSA
            elif 'sha512' in sig_alg_name.lower() and 'rsa' in sig_alg_name.lower():
                sig_alg = SignatureAlgorithm.SHA512_WITH_RSA
            elif 'sha256' in sig_alg_name.lower() and 'ecdsa' in sig_alg_name.lower():
                sig_alg = SignatureAlgorithm.ECDSA_WITH_SHA256
            elif 'sha384' in sig_alg_name.lower() and 'ecdsa' in sig_alg_name.lower():
                sig_alg = SignatureAlgorithm.ECDSA_WITH_SHA384
            elif 'sha512' in sig_alg_name.lower() and 'ecdsa' in sig_alg_name.lower():
                sig_alg = SignatureAlgorithm.ECDSA_WITH_SHA512
            elif 'ed25519' in sig_alg_name.lower():
                sig_alg = SignatureAlgorithm.ED25519
            elif 'sha1' in sig_alg_name.lower():
                sig_alg = SignatureAlgorithm.SHA1_WITH_RSA
            elif 'md5' in sig_alg_name.lower():
                sig_alg = SignatureAlgorithm.MD5_WITH_RSA
            
            # Determine PQC readiness
            pqc_ready = PQCReadiness.UNKNOWN
            if key_alg == KeyAlgorithm.RSA and key_size and key_size >= 3072:
                pqc_ready = PQCReadiness.VULNERABLE  # RSA is vulnerable, even at 3072
            elif key_alg == KeyAlgorithm.ECDSA and key_size and key_size >= 384:
                pqc_ready = PQCReadiness.VULNERABLE  # ECC is vulnerable
            elif key_alg == KeyAlgorithm.ED25519:
                pqc_ready = PQCReadiness.VULNERABLE  # Still vulnerable to quantum
            
            # Determine status
            now = datetime.utcnow()
            status = CertificateStatus.ACTIVE
            if cert.not_valid_after_utc < now:
                status = CertificateStatus.EXPIRED
            elif cert.not_valid_before_utc > now:
                status = CertificateStatus.PENDING
            
            days_remaining = (cert.not_valid_after_utc - now).days
            
            return CertificateRecord(
                certificate_subject=subject,
                subject_alternative_names=sans,
                serial_number=format(cert.serial_number, 'x'),
                issuer=cert.issuer.rfc4514_string(),
                key_algorithm=key_alg,
                key_size=key_size,
                signature_algorithm=sig_alg,
                not_before=cert.not_valid_before_utc,
                not_after=cert.not_valid_after_utc,
                days_remaining=days_remaining,
                status=status,
                source_ca=self.source,
                pqc_readiness=pqc_ready,
                pem_certificate=pem_data,
                **kwargs
            )
            
        except Exception as e:
            self.logger.error("certificate_parse_failed", error=str(e))
            return None


class EJBCADiscovery(CertificateDiscovery):
    """Discover certificates from EJBCA."""
    
    def __init__(self):
        super().____(DiscoverySource.EJBCA)
        self.base_url = EJBCA_URL
        self.auth = (EJBCA_USERNAME, EJBCA_PASSWORD) if EJBCA_USERNAME else None
    
    def discover(self) -> List[CertificateRecord]:
        """Discover certificates from EJBCA via REST API."""
        certificates = []
        
        if not self.auth:
            self.logger.warning("ejbca_credentials_not_configured")
            return certificates
        
        try:
            # EJBCA REST API endpoint for certificate search
            url = f"{self.base_url}/rest/v1/certificate/search"
            
            with httpx.Client(verify=False, timeout=30.0) as client:
                response = client.post(
                    url,
                    auth=self.auth,
                    json={
                        "maxNumberOfResults": 1000,
                        "criteria": [
                            {"property": "STATUS", "value": "CERT_ACTIVE", "operation": "EQUAL"}
                        ]
                    }
                )
                
                if response.status_code == 200:
                    data = response.json()
                    for cert_data in data.get("certificates", []):
                        pem = cert_data.get("certificate")
                        if pem:
                            record = self._parse_certificate(
                                pem,
                                hostname=cert_data.get("subjectDN", "").split("CN=")[-1].split(",")[0] if "CN=" in cert_data.get("subjectDN", "") else None,
                                certificate_profile=cert_data.get("certificateProfileName"),
                                metadata={
                                    "ejbca_end_entity": cert_data.get("endEntityProfileName"),
                                    "ejbca_ca_name": cert_data.get("issuerDN"),
                                }
                            )
                            if record:
                                certificates.append(record)
                    
                    self.logger.info("ejbca_discovery_complete", count=len(certificates))
                else:
                    self.logger.error("ejbca_discovery_failed", status=response.status_code)
                    
        except Exception as e:
            self.logger.error("ejbca_discovery_error", error=str(e))
        
        return certificates


class OpenBaoDiscovery(CertificateDiscovery):
    """Discover certificates from OpenBao PKI."""
    
    def __init__(self):
        super().__init__(DiscoverySource.OPENBAO_PKI)
        self.base_url = OPENBAO_URL
        self.token = OPENBAO_TOKEN
    
    def discover(self) -> List[CertificateRecord]:
        """Discover certificates from OpenBao PKI."""
        certificates = []
        
        if not self.token:
            self.logger.warning("openbao_token_not_configured")
            return certificates
        
        try:
            headers = {"X-Vault-Token": self.token}
            
            with httpx.Client(verify=False, timeout=30.0) as client:
                # List PKI roles
                roles_url = f"{self.base_url}/v1/pki/roles?list=true"
                roles_response = client.get(roles_url, headers=headers)
                
                if roles_response.status_code != 200:
                    self.logger.warning("openbao_no_pki_roles", status=roles_response.status_code)
                    return certificates
                
                roles = roles_response.json().get("data", {}).get("keys", [])
                
                for role in roles:
                    # List certificates for each role
                    certs_url = f"{self.base_url}/v1/pki/certs?list=true"
                    certs_response = client.get(certs_url, headers=headers)
                    
                    if certs_response.status_code == 200:
                        cert_keys = certs_response.json().get("data", {}).get("keys", [])
                        
                        for cert_key in cert_keys:
                            cert_url = f"{self.base_url}/v1/pki/cert/{cert_key}"
                            cert_response = client.get(cert_url, headers=headers)
                            
                            if cert_response.status_code == 200:
                                cert_data = cert_response.json().get("data", {})
                                pem = cert_data.get("certificate")
                                
                                if pem:
                                    record = self._parse_certificate(
                                        pem,
                                        certificate_profile=role,
                                        metadata={
                                            "openbao_role": role,
                                            "openbao_serial": cert_key,
                                        }
                                    )
                                    if record:
                                        certificates.append(record)
                
                self.logger.info("openbao_discovery_complete", count=len(certificates))
                
        except Exception as e:
            self.logger.error("openbao_discovery_error", error=str(e))
        
        return certificates


class KubernetesSecretDiscovery(CertificateDiscovery):
    """Discover certificates from Kubernetes TLS secrets."""
    
    def __init__(self):
        super().__init__(DiscoverySource.KUBERNETES_SECRET)
        self.api_url = KUBERNETES_API_URL
    
    def discover(self) -> List[CertificateRecord]:
        """Discover certificates from Kubernetes TLS secrets."""
        certificates = []
        
        try:
            # Read service account token
            with open('/var/run/secrets/kubernetes.io/serviceaccount/token', 'r') as f:
                token = f.read()
            
            headers = {
                "Authorization": f"Bearer {token}",
                "Accept": "application/json"
            }
            
            with httpx.Client(verify='/var/run/secrets/kubernetes.io/serviceaccount/ca.crt', timeout=30.0) as client:
                # List all secrets across all namespaces
                url = f"{self.api_url}/api/v1/secrets"
                response = client.get(url, headers=headers)
                
                if response.status_code == 200:
                    secrets = response.json().get("items", [])
                    
                    for secret in secrets:
                        secret_type = secret.get("type")
                        if secret_type == "kubernetes.io/tls":
                            data = secret.get("data", {})
                            tls_crt = data.get("tls.crt")
                            
                            if tls_crt:
                                pem = base64.b64decode(tls_crt).decode()
                                
                                metadata = secret.get("metadata", {})
                                record = self._parse_certificate(
                                    pem,
                                    hostname=metadata.get("annotations", {}).get("cert-manager.io/common-name"),
                                    application=metadata.get("labels", {}).get("app.kubernetes.io/name"),
                                    environment=metadata.get("labels", {}).get("environment"),
                                    owner=metadata.get("annotations", {}).get("owner"),
                                    metadata={
                                        "kubernetes_namespace": metadata.get("namespace"),
                                        "kubernetes_secret_name": metadata.get("name"),
                                        "cert_manager_issuer": metadata.get("annotations", {}).get("cert-manager.io/issuer-name"),
                                    }
                                )
                                if record:
                                    certificates.append(record)
                    
                    self.logger.info("kubernetes_discovery_complete", count=len(certificates))
                else:
                    self.logger.error("kubernetes_discovery_failed", status=response.status_code)
                    
        except Exception as e:
            self.logger.error("kubernetes_discovery_error", error=str(e))
        
        return certificates


class TLSScanDiscovery(CertificateDiscovery):
    """Discover certificates by scanning TLS endpoints."""
    
    def __init__(self):
        super().__init__(DiscoverySource.TLS_SCAN)
        self.targets = os.getenv("TLS_SCAN_TARGETS", "").split(",")
    
    def discover(self) -> List[CertificateRecord]:
        """Scan TLS endpoints for certificates."""
        certificates = []
        
        if not self.targets or self.targets == ['']:
            self.logger.warning("tls_scan_targets_not_configured")
            return certificates
        
        for target in self.targets:
            target = target.strip()
            if not target:
                continue
            
            try:
                host, port = target.split(":") if ":" in target else (target, "443")
                port = int(port)
                
                context = ssl.create_default_context()
                context.check_hostname = False
                context.verify_mode = ssl.CERT_NONE
                
                with socket.create_connection((host, port), timeout=10) as sock:
                    with context.wrap_socket(sock, server_hostname=host) as ssock:
                        cert_der = ssock.getpeercert(binary_form=True)
                        
                        if cert_der:
                            cert = x509.load_der_x509_certificate(cert_der)
                            pem = cert.public_bytes(serialization.Encoding.PEM).decode()
                            
                            record = self._parse_certificate(
                                pem,
                                hostname=host,
                                service=f"tls:{port}",
                                discovery_method="tls_scan",
                                metadata={
                                    "scan_target": target,
                                    "tls_version": ssock.version(),
                                }
                            )
                            if record:
                                certificates.append(record)
                                
            except Exception as e:
                self.logger.error("tls_scan_failed", target=target, error=str(e))
        
        self.logger.info("tls_scan_complete", count=len(certificates))
        return certificates


def store_certificates(certificates: List[CertificateRecord], db: Session):
    """Store discovered certificates in the database."""
    added = 0
    updated = 0
    
    for cert in certificates:
        try:
            # Check if certificate already exists by serial number
            existing = db.query(CertificateRecord).filter(
                CertificateRecord.serial_number == cert.serial_number
            ).first()
            
            if existing:
                # Update existing record
                for field, value in cert.dict(exclude_unset=True).items():
                    if field != 'id' and value is not None:
                        setattr(existing, field, value)
                existing.last_seen = datetime.utcnow()
                updated += 1
            else:
                # Insert new record
                db.add(cert)
                added += 1
            
            db.commit()
            
        except Exception as e:
            logger.error("certificate_store_failed", serial=cert.serial_number, error=str(e))
            db.rollback()
    
    return added, updated


def run_discovery():
    """Run all discovery jobs."""
    logger.info("discovery_run_starting")
    
    db = SessionLocal()
    total_added = 0
    total_updated = 0
    
    try:
        # Initialize discovery sources
        sources = [
            EJBCADiscovery(),
            OpenBaoDiscovery(),
            KubernetesSecretDiscovery(),
            TLSScanDiscovery(),
        ]
        
        for source in sources:
            try:
                logger.info("discovery_source_starting", source=source.source.value)
                certificates = source.discover()
                
                if certificates:
                    added, updated = store_certificates(certificates, db)
                    total_added += added
                    total_updated += updated
                    
                    logger.info(
                        "discovery_source_complete",
                        source=source.source.value,
                        found=len(certificates),
                        added=added,
                        updated=updated,
                    )
                else:
                    logger.info("discovery_source_empty", source=source.source.value)
                    
            except Exception as e:
                logger.error("discovery_source_failed", source=source.source.value, error=str(e))
        
        logger.info(
            "discovery_run_complete",
            total_added=total_added,
            total_updated=total_updated,
        )
        
    finally:
        db.close()


def main():
    """Main worker loop."""
    logger.info("cert_worker_starting", version="0.1.0")
    
    # Schedule discovery jobs
    schedule.every(6).hours.do(run_discovery)
    
    # Run initial discovery
    run_discovery()
    
    # Keep running
    while True:
        schedule.run_pending()
        time.sleep(60)


if __name__ == "__main__":
    main()
