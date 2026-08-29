"""
Certificate Service
Phase 6 — Multi-CA Abstraction Layer

High-level service that orchestrates certificate operations across
multiple CA providers.
"""

from typing import List, Optional, Dict, Any
from enum import Enum

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
from provider_interface import CAProviderInterface
from providers.ejbca import EJBCAProvider
from providers.openbao import OpenBaoProvider


class ProviderSelectionStrategy(str, Enum):
    """Strategies for selecting a CA provider."""
    PRIORITY = "priority"           # Use highest priority provider
    CAPABILITY = "capability"       # Use provider that supports operation
    ROUND_ROBIN = "round_robin"     # Rotate between providers
    HEALTH_CHECK = "health_check"   # Use healthiest provider
    EXPLICIT = "explicit"           # Use explicitly specified provider


class CertificateService:
    """
    Certificate Service orchestrates operations across multiple CA providers.
    
    This is the main entry point for certificate operations. It:
    1. Maintains a registry of CA providers
    2. Performs capability discovery
    3. Routes requests to appropriate providers
    4. Handles failover between providers
    5. Normalizes responses across different CAs
    
    Architecture:
    
    Application
         |
         v
    Certificate Service
         |
         +---> Capability Discovery
         |         |
         |         v
         |    Provider A supports op?
         |         | Yes
         |         v
         |    Route to Provider A
         |         |
         |         v
         |    Normalize response
         |
         +---> Provider B (fallback)
    """
    
    def __init__(self):
        self.providers: Dict[str, CAProviderInterface] = {}
        self.configs: Dict[str, ProviderConfig] = {}
        self.default_strategy = ProviderSelectionStrategy.CAPABILITY
    
    def register_provider(self, config: ProviderConfig) -> None:
        """
        Register a CA provider.
        
        Args:
            config: Provider configuration
        """
        if config.provider == CAProvider.EJBCA:
            provider = EJBCAProvider(config)
        elif config.provider == CAProvider.OPENBAO_PKI:
            provider = OpenBaoProvider(config)
        else:
            raise ValueError(f"Unknown provider: {config.provider}")
        
        self.providers[config.name] = provider
        self.configs[config.name] = config
    
    def unregister_provider(self, name: str) -> None:
        """Remove a provider from the registry."""
        if name in self.providers:
            del self.providers[name]
            del self.configs[name]
    
    def list_providers(self) -> List[str]:
        """List all registered provider names."""
        return list(self.providers.keys())
    
    def get_provider_capabilities(self, name: str) -> CAProviderCapabilities:
        """Get capabilities of a specific provider."""
        if name not in self.providers:
            raise ValueError(f"Provider not found: {name}")
        return self.providers[name].get_capabilities()
    
    def check_capability(self, provider_name: str, 
                        operation: CAOperation) -> CapabilityCheck:
        """Check if a provider supports an operation."""
        if provider_name not in self.providers:
            raise ValueError(f"Provider not found: {provider_name}")
        return self.providers[provider_name].check_capability(operation)
    
    def select_provider(self, 
                       operation: CAOperation,
                       strategy: Optional[ProviderSelectionStrategy] = None,
                       preferred_provider: Optional[str] = None) -> Optional[str]:
        """
        Select a provider for an operation.
        
        Args:
            operation: The operation to perform
            strategy: Selection strategy (defaults to capability-based)
            preferred_provider: Explicitly preferred provider
            
        Returns:
            Name of selected provider, or None if no suitable provider found
        """
        strategy = strategy or self.default_strategy
        
        # If explicit provider requested, check it first
        if preferred_provider and preferred_provider in self.providers:
            check = self.providers[preferred_provider].check_capability(operation)
            if check.supported:
                return preferred_provider
        
        # Filter providers that support the operation
        capable_providers = []
        for name, provider in self.providers.items():
            caps = provider.get_capabilities()
            if operation in caps.operations:
                capable_providers.append(name)
        
        if not capable_providers:
            return None
        
        if strategy == ProviderSelectionStrategy.PRIORITY:
            # Select by priority (lowest number = highest priority)
            return min(capable_providers, 
                      key=lambda n: self.configs[n].priority)
        
        elif strategy == ProviderSelectionStrategy.HEALTH_CHECK:
            # Select healthiest provider
            healthiest = None
            best_health = False
            
            for name in capable_providers:
                status = self.providers[name].get_status()
                if status.healthy and not best_health:
                    healthiest = name
                    best_health = True
            
            return healthiest or capable_providers[0]
        
        elif strategy == ProviderSelectionStrategy.ROUND_ROBIN:
            # Simple round-robin (would need state in production)
            return capable_providers[0]
        
        else:  # CAPABILITY or default
            return capable_providers[0]
    
    def issue_certificate(self, 
                         request: CertificateRequest,
                         provider_name: Optional[str] = None,
                         strategy: Optional[ProviderSelectionStrategy] = None
                         ) -> CertificateResponse:
        """
        Issue a certificate using the best available provider.
        
        Args:
            request: Certificate request
            provider_name: Explicit provider to use
            strategy: Provider selection strategy
            
        Returns:
            CertificateResponse
            
        Raises:
            ValueError: If no provider supports issuance
            Exception: If issuance fails
        """
        selected = self.select_provider(
            CAOperation.ISSUE_CERTIFICATE,
            strategy=strategy,
            preferred_provider=provider_name
        )
        
        if not selected:
            raise ValueError(
                "No provider supports certificate issuance. "
                "Registered providers: " + ", ".join(self.list_providers())
            )
        
        provider = self.providers[selected]
        return provider.issue_certificate(request)
    
    def revoke_certificate(self,
                          request: RevocationRequest,
                          provider_name: Optional[str] = None
                          ) -> RevocationResponse:
        """
        Revoke a certificate.
        
        Args:
            request: Revocation request
            provider_name: Explicit provider to use
            
        Returns:
            RevocationResponse
        """
        selected = self.select_provider(
            CAOperation.REVOKE_CERTIFICATE,
            preferred_provider=provider_name
        )
        
        if not selected:
            raise ValueError("No provider supports certificate revocation")
        
        provider = self.providers[selected]
        return provider.revoke_certificate(request)
    
    def get_certificate(self,
                       serial_number: str,
                       provider_name: Optional[str] = None
                       ) -> Optional[CertificateResponse]:
        """
        Get a certificate by serial number.
        
        Args:
            serial_number: Certificate serial number
            provider_name: Explicit provider to search
            
        Returns:
            CertificateResponse or None
        """
        if provider_name:
            if provider_name in self.providers:
                return self.providers[provider_name].get_certificate(serial_number)
            return None
        
        # Search all providers
        for name, provider in self.providers.items():
            cert = provider.get_certificate(serial_number)
            if cert:
                return cert
        
        return None
    
    def get_ca_chain(self, provider_name: Optional[str] = None) -> CAChainResponse:
        """
        Get CA chain from a provider.
        
        Args:
            provider_name: Explicit provider to use
            
        Returns:
            CAChainResponse
        """
        selected = self.select_provider(
            CAOperation.GET_CA_CHAIN,
            preferred_provider=provider_name
        )
        
        if not selected:
            raise ValueError("No provider supports CA chain retrieval")
        
        return self.providers[selected].get_ca_chain()
    
    def get_status(self, provider_name: Optional[str] = None) -> Dict[str, CAStatus]:
        """
        Get status of all providers or a specific provider.
        
        Args:
            provider_name: Specific provider to check
            
        Returns:
            Dictionary of provider name -> CAStatus
        """
        if provider_name:
            if provider_name in self.providers:
                return {provider_name: self.providers[provider_name].get_status()}
            return {}
        
        return {name: provider.get_status() 
                for name, provider in self.providers.items()}
    
    def get_all_capabilities(self) -> Dict[str, CAProviderCapabilities]:
        """
        Get capabilities of all providers.
        
        Returns:
            Dictionary of provider name -> capabilities
        """
        return {name: provider.get_capabilities() 
                for name, provider in self.providers.items()}


# Example usage and configuration
EXAMPLE_CONFIGS = [
    ProviderConfig(
        provider=CAProvider.EJBCA,
        name="ejbca-primary",
        enabled=True,
        priority=10,
        base_url="https://ejbca-ejbca-ce:8443/ejbca",
        auth_type="userpass",
        credentials={
            "username": "superadmin",
            "password": "changeme",
            "ca_name": "ManagementCA",
        },
        default_certificate_profile="TLS Server",
        default_validity_days=365,
    ),
    ProviderConfig(
        provider=CAProvider.OPENBAO_PKI,
        name="openbao-pki",
        enabled=True,
        priority=20,
        base_url="https://openbao:8200",
        auth_type="token",
        credentials={
            "token": "hvs.xxxxxx",
            "mount_path": "pki",
            "default_role": "default",
        },
        default_validity_days=30,
        max_validity_days=90,
    ),
]
