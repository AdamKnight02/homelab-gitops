# CA Service: Multi-CA Abstraction Layer

## Phase 6 — Multi-CA Abstraction

This service provides a unified interface for certificate operations across multiple Certificate Authorities.

### Why Abstraction Matters

**Vendor Lock-in Prevention**: Your application shouldn't depend on EJBCA-specific APIs. If you need to migrate to OpenBao, Smallstep, or a cloud CA, you only change the provider configuration, not your application code.

**Multi-CA Strategy**: Different use cases need different CAs:
- **EJBCA**: Long-lived human/IoT certificates, complex profiles
- **OpenBao PKI**: Short-lived service certificates, automated infrastructure
- **Smallstep**: Developer-friendly, ACME protocol, workload identity
- **Cloud CAs**: AWS Private CA, Azure Key Vault, Google CA Service

**Capability Discovery**: Not all CAs support the same operations. The abstraction layer lets you check capabilities before attempting operations.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Certificate Service                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  issue()    │  │  revoke()   │  │  get_ca_chain()     │ │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘ │
│         │                │                    │            │
│  ┌──────┴────────────────┴────────────────────┴──────┐    │
│  │              Provider Selection                      │    │
│  │  (priority | capability | health | round-robin)    │    │
│  └──────┬────────────────┬────────────────────┬──────┘    │
└─────────┼────────────────┼────────────────────┼───────────┘
          │                │                    │
          v                v                    v
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│   EJBCA Provider│ │ OpenBao Provider│ │ Smallstep Prov. │
│   ├─ Profiles   │ │ ├─ Roles        │ │ ├─ ACME         │
│   ├─ End Entity │ │ ├─ Short-lived  │ │ ├─ JWK          │
│   ├─ CRL/OCSP   │ │ └─ Workload ID  │ │ └─ SSH Certs    │
│   └─ Multi-CA   │ └─────────────────┘ └─────────────────┘
└─────────────────┘
```

### Provider Capabilities

| Capability | EJBCA | OpenBao | Smallstep |
|-----------|-------|---------|-----------|
| Issue certificates | ✅ | ✅ | ✅ |
| Revoke certificates | ✅ | ✅ | ✅ |
| Certificate profiles | ✅ | ❌ (roles) | ❌ (templates) |
| End entity profiles | ✅ | ❌ | ❌ |
| CRL generation | ✅ | ✅ | ✅ |
| OCSP responder | ✅ | ⚠️ Limited | ✅ |
| Short-lived certs (<24h) | ⚠️ | ✅ | ✅ |
| ACME protocol | ❌ | ❌ | ✅ |
| Workload identity | ❌ | ✅ | ✅ |
| SCEP | ✅ | ❌ | ❌ |
| EST | ✅ | ❌ | ❌ |

### Usage Example

```python
from certificate_service import CertificateService
from models import ProviderConfig, CAProvider, CertificateRequest

# Initialize service
service = CertificateService()

# Register providers
service.register_provider(ProviderConfig(
    provider=CAProvider.EJBCA,
    name="ejbca-primary",
    base_url="https://ejbca:8443",
    credentials={"username": "admin", "password": "secret"},
))

service.register_provider(ProviderConfig(
    provider=CAProvider.OPENBAO_PKI,
    name="openbao-pki",
    base_url="https://openbao:8200",
    credentials={"token": "hvs.xxx"},
))

# Check capabilities
caps = service.get_all_capabilities()
print(f"EJBCA supports: {caps['ejbca-primary'].operations}")
print(f"OpenBao supports: {caps['openbao-pki'].operations}")

# Issue certificate (auto-selects best provider)
request = CertificateRequest(
    common_name="api.example.com",
    subject_alternative_names=["api.example.com", "*.example.com"],
    validity_days=30,
)
response = service.issue_certificate(request)

# Or explicitly use a provider
response = service.issue_certificate(request, provider_name="openbao-pki")
```

### Design Principles

1. **Normalize, Don't Homogenize**: Different CAs have different capabilities. Don't pretend they're identical. Instead, expose capabilities and let the application make informed decisions.

2. **Fail Gracefully**: If one provider fails, try another. If no provider supports an operation, return a clear error with alternatives.

3. **Capability Discovery First**: Always check capabilities before attempting operations. This prevents runtime failures.

4. **Preserve Provider-Specific Features**: The abstraction shouldn't prevent using EJBCA's certificate profiles or OpenBao's roles. Expose these as optional parameters.

5. **Provider-Native Configuration**: Each provider has its own configuration. Don't force a one-size-fits-all config.
