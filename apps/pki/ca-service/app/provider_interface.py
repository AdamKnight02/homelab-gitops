"""
CA Provider Interface
Phase 6 — Multi-CA Abstraction Layer

Abstract base class that all CA providers must implement.
"""

from abc import ABC, abstractmethod
from typing import List, Optional, Dict, Any

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


class CAProviderInterface(ABC):
    """
    Abstract interface for Certificate Authority providers.
    
    All CA implementations (EJBCA, OpenBao, Smallstep, etc.) must implement
    this interface. The interface normalizes different CA APIs into a common
    set of operations.
    
    Why abstraction matters:
    - Vendor lock-in: Don't let your application depend on one CA's quirks
    - Migration: Move from one CA to another without rewriting application code
    - Multi-CA: Use different CAs for different use cases (internal vs external)
    - Testing: Mock the interface for unit tests
    - Feature parity: Know what each CA can and cannot do
    """
    
    def __init__(self, config: ProviderConfig):
        self.config = config
        self.provider = config.provider
        self.name = config.name
    
    @abstractmethod
    def get_capabilities(self) -> CAProviderCapabilities:
        """
        Return the capabilities of this CA provider.
        
        This is critical for capability discovery. The application should
        check capabilities before attempting operations.
        
        Example:
            caps = provider.get_capabilities()
            if CAOperation.ISSUE_CERTIFICATE not in caps.operations:
                raise UnsupportedOperation("This CA cannot issue certificates")
        """
        pass
    
    @abstractmethod
    def get_status(self) -> CAStatus:
        """
        Check if the CA is healthy and available.
        
        Returns:
            CAStatus with health information
        """
        pass
    
    @abstractmethod
    def issue_certificate(self, request: CertificateRequest) -> CertificateResponse:
        """
        Issue a new certificate.
        
        Args:
            request: Certificate request parameters
            
        Returns:
            CertificateResponse with the issued certificate
            
        Raises:
            UnsupportedOperation: If this CA doesn't support issuance
            CertificateError: If issuance fails
        """
        pass
    
    @abstractmethod
    def revoke_certificate(self, request: RevocationRequest) -> RevocationResponse:
        """
        Revoke a certificate.
        
        Args:
            request: Revocation request with serial number and reason
            
        Returns:
            RevocationResponse confirming the revocation
            
        Raises:
            UnsupportedOperation: If this CA doesn't support revocation
            CertificateNotFound: If certificate doesn't exist
        """
        pass
    
    @abstractmethod
    def get_certificate(self, serial_number: str) -> Optional[CertificateResponse]:
        """
        Retrieve a certificate by serial number.
        
        Args:
            serial_number: Certificate serial number
            
        Returns:
            CertificateResponse or None if not found
        """
        pass
    
    @abstractmethod
    def get_ca_chain(self) -> CAChainResponse:
        """
        Get the CA certificate chain.
        
        Returns:
            CAChainResponse with the chain of trust
        """
        pass
    
    @abstractmethod
    def renew_certificate(self, serial_number: str, 
                         validity_days: Optional[int] = None) -> CertificateResponse:
        """
        Renew an existing certificate.
        
        Not all CAs support true renewal. Some may issue a new certificate
        with the same subject.
        
        Args:
            serial_number: Certificate to renew
            validity_days: Optional override for validity period
            
        Returns:
            CertificateResponse with the renewed certificate
            
        Raises:
            UnsupportedOperation: If this CA doesn't support renewal
        """
        pass
    
    def check_capability(self, operation: CAOperation) -> CapabilityCheck:
        """
        Check if this provider supports a specific operation.
        
        This is a convenience method that wraps get_capabilities().
        
        Args:
            operation: The operation to check
            
        Returns:
            CapabilityCheck with result and alternatives
        """
        caps = self.get_capabilities()
        supported = operation in caps.operations
        
        reason = None
        alternatives = []
        
        if not supported:
            reason = f"{self.provider.value} does not support {operation.value}"
            
            # Suggest alternatives
            if operation == CAOperation.RENEW_CERTIFICATE:
                alternatives = ["Issue a new certificate with the same parameters"]
            elif operation == CAOperation.GET_OCSP_RESPONSE:
                alternatives = ["Use CRL for revocation checking"]
        
        return CapabilityCheck(
            provider=self.provider,
            operation=operation,
            supported=supported,
            reason=reason,
            alternatives=alternatives,
        )
    
    def validate_request(self, request: CertificateRequest) -> List[str]:
        """
        Validate a certificate request against this provider's capabilities.
        
        Args:
            request: Certificate request to validate
            
        Returns:
            List of validation errors (empty if valid)
        """
        errors = []
        caps = self.get_capabilities()
        
        # Check key algorithm
        if request.key_algorithm not in caps.supported_key_algorithms:
            errors.append(
                f"Key algorithm {request.key_algorithm} not supported. "
                f"Supported: {caps.supported_key_algorithms}"
            )
        
        # Check key size
        if request.key_algorithm == "RSA" and request.key_size < 2048:
            errors.append("RSA key size must be at least 2048 bits")
        
        # Check validity period
        if caps.max_certificate_validity_days:
            if request.validity_days > caps.max_certificate_validity_days:
                errors.append(
                    f"Validity period {request.validity_days} days exceeds maximum "
                    f"{caps.max_certificate_validity_days} days"
                )
        
        # Check certificate profile
        if request.certificate_profile:
            if caps.certificate_profiles:
                if request.certificate_profile not in caps.certificate_profiles:
                    errors.append(
                        f"Certificate profile {request.certificate_profile} not available. "
                        f"Available: {caps.certificate_profiles}"
                    )
        
        # Check SANs
        if request.subject_alternative_names:
            if caps.max_sans and len(request.subject_alternative_names) > caps.max_sans:
                errors.append(
                    f"Too many SANs: {len(request.subject_alternative_names)}. "
                    f"Maximum: {caps.max_sans}"
                )
        
        return errors
