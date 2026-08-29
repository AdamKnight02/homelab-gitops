"""
EJBCA Provider Implementation
Phase 6 — Multi-CA Abstraction Layer
"""

import base64
from datetime import datetime
from typing import List, Optional, Dict, Any

import httpx

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
    Capability,
)
from provider_interface import CAProviderInterface


class EJBCAProvider(CAProviderInterface):
    """
    EJBCA Certificate Authority Provider.
    
    EJBCA is an enterprise-grade CA with rich features:
    - Certificate profiles (templates for different certificate types)
    - End entity profiles (templates for subject fields)
    - Full CRL and OCSP support
    - Multi-level CA hierarchies
    - RA (Registration Authority) functionality
    
    Limitations:
    - Complex configuration
    - Requires understanding of profiles
    - Not designed for short-lived certificates (minutes/hours)
    """
    
    def __init__(self, config: ProviderConfig):
        super().__init__(config)
        self.base_url = config.base_url or "https://ejbca-ejbca-ce:8443/ejbca"
        self.auth = (
            config.credentials.get("username", ""),
            config.credentials.get("password", "")
        )
        self.ca_name = config.credentials.get("ca_name", "ManagementCA")
    
    def get_capabilities(self) -> CAProviderCapabilities:
        """Return EJBCA capabilities."""
        return CAProviderCapabilities(
            provider=CAProvider.EJBCA,
            operations={
                CAOperation.ISSUE_CERTIFICATE,
                CAOperation.REVOKE_CERTIFICATE,
                CAOperation.GET_CERTIFICATE,
                CAOperation.GET_CA_CHAIN,
                CAOperation.GET_STATUS,
                CAOperation.RENEW_CERTIFICATE,
                CAOperation.LIST_CERTIFICATES,
                CAOperation.GENERATE_CRL,
                CAOperation.GET_OCSP_RESPONSE,
            },
            capabilities={
                Capability.ISSUE,
                Capability.REVOKE,
                Capability.RENEW,
                Capability.READ,
                Capability.LIST,
                Capability.CA_CHAIN,
                Capability.CRL,
                Capability.OCSP,
                Capability.CERTIFICATE_PROFILES,
                Capability.END_ENTITY_PROFILES,
                Capability.USER_AUTH,
                Capability.CERT_AUTH,
            },
            certificate_profiles=[
                "TLS Server",
                "TLS Client",
                "Code Signing",
                "Email Protection",
                "OCSP Signer",
            ],
            max_certificate_validity_days=365 * 10,  # 10 years max
            supports_custom_extensions=True,
            supports_subject_alternative_names=True,
            max_sans=100,
            supported_key_algorithms=["RSA", "ECDSA"],
            supported_signature_algorithms=[
                "SHA256withRSA",
                "SHA384withRSA",
                "SHA512withRSA",
                "SHA256withECDSA",
                "SHA384withECDSA",
                "SHA512withECDSA",
            ],
        )
    
    def get_status(self) -> CAStatus:
        """Check EJBCA health."""
        try:
            with httpx.Client(verify=False, timeout=10.0) as client:
                response = client.get(
                    f"{self.base_url}/rest/v1/ca",
                    auth=self.auth
                )
                
                if response.status_code == 200:
                    ca_data = response.json()
                    return CAStatus(
                        provider=CAProvider.EJBCA,
                        healthy=True,
                        version="9.3.7",
                        ca_certificates=[ca.get("subjectDN", "") for ca in ca_data],
                    )
                else:
                    return CAStatus(
                        provider=CAProvider.EJBCA,
                        healthy=False,
                        message=f"HTTP {response.status_code}",
                    )
        except Exception as e:
            return CAStatus(
                provider=CAProvider.EJBCA,
                healthy=False,
                message=str(e),
            )
    
    def issue_certificate(self, request: CertificateRequest) -> CertificateResponse:
        """Issue certificate via EJBCA."""
        # Validate request
        errors = self.validate_request(request)
        if errors:
            raise ValueError(f"Invalid request: {'; '.join(errors)}")
        
        try:
            with httpx.Client(verify=False, timeout=30.0) as client:
                # EJBCA uses certificate profiles and end entity profiles
                # This is a simplified example
                payload = {
                    "certificateProfileName": request.certificate_profile or "TLS Server",
                    "endEntityProfileName": "EMPTY",
                    "caName": self.ca_name,
                    "subjectDN": f"CN={request.common_name}",
                    "subjectAltName": ",".join(request.subject_alternative_names),
                    "keyAlgo": request.key_algorithm,
                    "keySpec": str(request.key_size),
                    "validityDays": request.validity_days,
                }
                
                response = client.post(
                    f"{self.base_url}/rest/v1/certificate/pkcs10enroll",
                    auth=self.auth,
                    json=payload
                )
                
                if response.status_code == 200:
                    data = response.json()
                    return CertificateResponse(
                        serial_number=data.get("serialNumber", ""),
                        certificate_pem=data.get("certificate", ""),
                        ca_chain_pem=[data.get("caCertificate", "")],
                        not_before=datetime.utcnow(),
                        not_after=datetime.utcnow(),  # Parse from cert
                        issuer=data.get("issuerDN", ""),
                        subject=data.get("subjectDN", ""),
                        ca_provider=CAProvider.EJBCA,
                        certificate_profile=request.certificate_profile,
                    )
                else:
                    raise Exception(f"EJBCA issuance failed: {response.status_code} {response.text}")
                    
        except Exception as e:
            raise Exception(f"Certificate issuance failed: {str(e)}")
    
    def revoke_certificate(self, request: RevocationRequest) -> RevocationResponse:
        """Revoke certificate in EJBCA."""
        try:
            with httpx.Client(verify=False, timeout=30.0) as client:
                response = client.post(
                    f"{self.base_url}/rest/v1/certificate/{request.serial_number}/revoke",
                    auth=self.auth,
                    json={"reason": request.reason}
                )
                
                if response.status_code == 200:
                    return RevocationResponse(
                        serial_number=request.serial_number,
                        revoked=True,
                        revocation_date=datetime.utcnow(),
                        reason=request.reason,
                    )
                else:
                    raise Exception(f"Revocation failed: {response.status_code}")
                    
        except Exception as e:
            raise Exception(f"Certificate revocation failed: {str(e)}")
    
    def get_certificate(self, serial_number: str) -> Optional[CertificateResponse]:
        """Get certificate by serial number."""
        try:
            with httpx.Client(verify=False, timeout=10.0) as client:
                response = client.get(
                    f"{self.base_url}/rest/v1/certificate/{serial_number}",
                    auth=self.auth
                )
                
                if response.status_code == 200:
                    data = response.json()
                    return CertificateResponse(
                        serial_number=serial_number,
                        certificate_pem=data.get("certificate", ""),
                        not_before=datetime.utcnow(),
                        not_after=datetime.utcnow(),
                        issuer=data.get("issuerDN", ""),
                        subject=data.get("subjectDN", ""),
                        ca_provider=CAProvider.EJBCA,
                    )
                return None
                
        except Exception:
            return None
    
    def get_ca_chain(self) -> CAChainResponse:
        """Get EJBCA CA chain."""
        try:
            with httpx.Client(verify=False, timeout=10.0) as client:
                response = client.get(
                    f"{self.base_url}/rest/v1/ca",
                    auth=self.auth
                )
                
                if response.status_code == 200:
                    ca_data = response.json()
                    certs = [ca.get("certificate", "") for ca in ca_data]
                    
                    return CAChainResponse(
                        provider=CAProvider.EJBCA,
                        ca_certificates=certs,
                        root_certificate=certs[-1] if certs else None,
                        intermediate_certificates=certs[:-1] if len(certs) > 1 else [],
                    )
                else:
                    raise Exception(f"Failed to get CA chain: {response.status_code}")
                    
        except Exception as e:
            raise Exception(f"Failed to get CA chain: {str(e)}")
    
    def renew_certificate(self, serial_number: str, 
                         validity_days: Optional[int] = None) -> CertificateResponse:
        """Renew certificate in EJBCA."""
        # EJBCA supports renewal through re-enrollment
        # This is a simplified implementation
        try:
            with httpx.Client(verify=False, timeout=30.0) as client:
                response = client.post(
                    f"{self.base_url}/rest/v1/certificate/{serial_number}/renew",
                    auth=self.auth,
                    json={"validityDays": validity_days or 365}
                )
                
                if response.status_code == 200:
                    data = response.json()
                    return CertificateResponse(
                        serial_number=data.get("serialNumber", ""),
                        certificate_pem=data.get("certificate", ""),
                        not_before=datetime.utcnow(),
                        not_after=datetime.utcnow(),
                        issuer=data.get("issuerDN", ""),
                        subject=data.get("subjectDN", ""),
                        ca_provider=CAProvider.EJBCA,
                    )
                else:
                    raise Exception(f"Renewal failed: {response.status_code}")
                    
        except Exception as e:
            raise Exception(f"Certificate renewal failed: {str(e)}")
