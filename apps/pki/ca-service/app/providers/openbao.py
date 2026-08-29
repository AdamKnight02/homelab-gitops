"""
OpenBao PKI Provider Implementation
Phase 6 — Multi-CA Abstraction Layer
"""

from datetime import datetime
from typing import List, Optional, Dict, Any

import httpx

from models import (
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


class OpenBaoProvider(CAProviderInterface):
    """
    OpenBao PKI Provider.
    
    OpenBao (HashiCorp Vault fork) PKI is designed for:
    - Short-lived certificates (hours to days)
    - Automated infrastructure (not human users)
    - Role-based issuance (not individual end entities)
    - Dynamic secrets (certificates are secrets)
    
    Limitations:
    - No certificate profiles (uses roles instead)
    - No end entity profiles
    - Limited OCSP support
    - CRLs are generated but not as feature-rich as EJBCA
    - Not designed for long-lived certificates (years)
    
    Strengths:
    - API-first design
    - Perfect for service mesh and workload identity
    - Easy automation
    - Built for cloud-native environments
    """
    
    def __init__(self, config: ProviderConfig):
        super().__init__(config)
        self.base_url = config.base_url or "https://openbao:8200"
        self.token = config.credentials.get("token", "")
        self.mount_path = config.credentials.get("mount_path", "pki")
        self.default_role = config.credentials.get("default_role", "default")
    
    def get_capabilities(self) -> CAProviderCapabilities:
        """Return OpenBao PKI capabilities."""
        return CAProviderCapabilities(
            provider=CAProvider.OPENBAO_PKI,
            operations={
                CAOperation.ISSUE_CERTIFICATE,
                CAOperation.REVOKE_CERTIFICATE,
                CAOperation.GET_CERTIFICATE,
                CAOperation.GET_CA_CHAIN,
                CAOperation.GET_STATUS,
                CAOperation.LIST_CERTIFICATES,
                CAOperation.GENERATE_CRL,
            },
            capabilities={
                Capability.ISSUE,
                Capability.REVOKE,
                Capability.READ,
                Capability.LIST,
                Capability.CA_CHAIN,
                Capability.CRL,
                Capability.ROLES,
                Capability.TOKEN_AUTH,
                Capability.SHORT_LIVED,
                Capability.WORKLOAD_IDENTITY,
            },
            certificate_profiles=[],  # OpenBao uses roles, not profiles
            max_certificate_validity_days=365 * 3,  # 3 years max (configurable)
            supports_custom_extensions=False,  # Limited extension support
            supports_subject_alternative_names=True,
            max_sans=64,  # Default limit
            supported_key_algorithms=["RSA", "ECDSA", "Ed25519"],
            supported_signature_algorithms=[
                "SHA256withRSA",
                "SHA384withRSA",
                "SHA512withRSA",
                "SHA256withECDSA",
                "SHA384withECDSA",
                "SHA512withECDSA",
                "Ed25519",
            ],
        )
    
    def get_status(self) -> CAStatus:
        """Check OpenBao PKI health."""
        try:
            headers = {"X-Vault-Token": self.token}
            
            with httpx.Client(verify=False, timeout=10.0) as client:
                # Check if PKI mount exists
                response = client.get(
                    f"{self.base_url}/v1/sys/mounts",
                    headers=headers
                )
                
                if response.status_code == 200:
                    mounts = response.json().get("data", {})
                    pki_mount = mounts.get(f"{self.mount_path}/", {})
                    
                    if pki_mount:
                        return CAStatus(
                            provider=CAProvider.OPENBAO_PKI,
                            healthy=True,
                            version=pki_mount.get("options", {}).get("version", "unknown"),
                            message="PKI mount active",
                        )
                    else:
                        return CAStatus(
                            provider=CAProvider.OPENBAO_PKI,
                            healthy=False,
                            message=f"PKI mount '{self.mount_path}' not found",
                        )
                else:
                    return CAStatus(
                        provider=CAProvider.OPENBAO_PKI,
                        healthy=False,
                        message=f"HTTP {response.status_code}",
                    )
        except Exception as e:
            return CAStatus(
                provider=CAProvider.OPENBAO_PKI,
                healthy=False,
                message=str(e),
            )
    
    def issue_certificate(self, request: CertificateRequest) -> CertificateResponse:
        """Issue certificate via OpenBao PKI."""
        errors = self.validate_request(request)
        if errors:
            raise ValueError(f"Invalid request: {'; '.join(errors)}")
        
        try:
            headers = {"X-Vault-Token": self.token}
            
            # OpenBao uses roles for certificate configuration
            role = request.certificate_profile or self.default_role
            
            payload = {
                "common_name": request.common_name,
                "ttl": f"{request.validity_days * 24}h",
            }
            
            if request.subject_alternative_names:
                payload["alt_names"] = ",".join(request.subject_alternative_names)
            
            if request.ip_sans:
                payload["ip_sans"] = ",".join(request.ip_sans)
            
            with httpx.Client(verify=False, timeout=30.0) as client:
                response = client.post(
                    f"{self.base_url}/v1/{self.mount_path}/issue/{role}",
                    headers=headers,
                    json=payload
                )
                
                if response.status_code == 200:
                    data = response.json().get("data", {})
                    
                    return CertificateResponse(
                        serial_number=data.get("serial_number", ""),
                        certificate_pem=data.get("certificate", ""),
                        ca_chain_pem=data.get("ca_chain", []),
                        private_key_pem=data.get("private_key", ""),
                        not_before=datetime.utcnow(),
                        not_after=datetime.utcnow(),  # Parse from cert
                        issuer="",  # Extract from cert
                        subject=f"CN={request.common_name}",
                        subject_alternative_names=request.subject_alternative_names,
                        ca_provider=CAProvider.OPENBAO_PKI,
                        certificate_profile=role,
                    )
                else:
                    raise Exception(f"OpenBao issuance failed: {response.status_code} {response.text}")
                    
        except Exception as e:
            raise Exception(f"Certificate issuance failed: {str(e)}")
    
    def revoke_certificate(self, request: RevocationRequest) -> RevocationResponse:
        """Revoke certificate in OpenBao."""
        try:
            headers = {"X-Vault-Token": self.token}
            
            with httpx.Client(verify=False, timeout=30.0) as client:
                response = client.post(
                    f"{self.base_url}/v1/{self.mount_path}/revoke",
                    headers=headers,
                    json={"serial_number": request.serial_number}
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
            headers = {"X-Vault-Token": self.token}
            
            with httpx.Client(verify=False, timeout=10.0) as client:
                response = client.get(
                    f"{self.base_url}/v1/{self.mount_path}/cert/{serial_number}",
                    headers=headers
                )
                
                if response.status_code == 200:
                    data = response.json().get("data", {})
                    return CertificateResponse(
                        serial_number=serial_number,
                        certificate_pem=data.get("certificate", ""),
                        not_before=datetime.utcnow(),
                        not_after=datetime.utcnow(),
                        issuer="",
                        subject="",
                        ca_provider=CAProvider.OPENBAO_PKI,
                    )
                return None
                
        except Exception:
            return None
    
    def get_ca_chain(self) -> CAChainResponse:
        """Get OpenBao CA chain."""
        try:
            headers = {"X-Vault-Token": self.token}
            
            with httpx.Client(verify=False, timeout=10.0) as client:
                # Get CA certificate
                ca_response = client.get(
                    f"{self.base_url}/v1/{self.mount_path}/ca/pem",
                    headers=headers
                )
                
                # Get CA chain
                chain_response = client.get(
                    f"{self.base_url}/v1/{self.mount_path}/ca_chain",
                    headers=headers
                )
                
                ca_cert = ca_response.text if ca_response.status_code == 200 else ""
                chain_certs = []
                
                if chain_response.status_code == 200:
                    # Parse chain response
                    chain_text = chain_response.text
                    # Split PEM blocks
                    chain_certs = self._split_pem_certs(chain_text)
                
                return CAChainResponse(
                    provider=CAProvider.OPENBAO_PKI,
                    ca_certificates=chain_certs,
                    root_certificate=ca_cert,
                    intermediate_certificates=chain_certs[:-1] if len(chain_certs) > 1 else [],
                )
                
        except Exception as e:
            raise Exception(f"Failed to get CA chain: {str(e)}")
    
    def renew_certificate(self, serial_number: str,
                         validity_days: Optional[int] = None) -> CertificateResponse:
        """
        Renew certificate in OpenBao.
        
        OpenBao doesn't support true renewal. We must issue a new certificate
        with the same parameters.
        """
        # Get existing certificate to extract parameters
        existing = self.get_certificate(serial_number)
        if not existing:
            raise Exception(f"Certificate {serial_number} not found")
        
        # Parse certificate to get CN and SANs
        # For simplicity, we'll require the caller to provide a new request
        raise UnsupportedOperation(
            "OpenBao does not support certificate renewal. "
            "Issue a new certificate instead."
        )
    
    def _split_pem_certs(self, pem_text: str) -> List[str]:
        """Split concatenated PEM certificates."""
        certs = []
        current = []
        
        for line in pem_text.strip().split('\n'):
            if line.startswith('-----BEGIN CERTIFICATE-----'):
                current = [line]
            elif line.startswith('-----END CERTIFICATE-----'):
                current.append(line)
                certs.append('\n'.join(current))
                current = []
            elif current:
                current.append(line)
        
        return certs


class UnsupportedOperation(Exception):
    """Raised when an operation is not supported by the provider."""
    pass
