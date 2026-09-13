# External CA Adapter Registry

## Overview

This document defines the provider-neutral registry for external CA integrations. The registry maps normalized provider names to their integration types, capabilities, and requirements. Provider-specific implementation details remain below the platform abstraction.

---

## Normalized Provider Enum

The following canonical identifiers are used internally across Terraform, pipelines, customer configs, and GitOps:

```yaml
# Canonical provider identifiers (lowercase, no spaces)
providers:
  - none
  - letsencrypt
  - digicert
  - sectigo
  - globalsign
  - entrust
  - godaddy
  - custom
```

**Display names** (for pipeline UI only):
| Canonical | Display Name |
|-----------|-------------|
| none | None |
| letsencrypt | Let's Encrypt |
| digicert | DigiCert |
| sectigo | Sectigo |
| globalsign | GlobalSign |
| entrust | Entrust |
| godaddy | GoDaddy |
| custom | Custom / Other |

---

## Integration Types

| Type | Description | Protocol |
|------|-------------|----------|
| `acme` | ACME protocol (RFC 8555) | ACME v2 |
| `anyca` | REST AnyCA gateway | REST/HTTPS |
| `native_api` | Provider-native API | Varies |
| `custom` | Custom adapter | Configurable |

---

## Provider Registry

```yaml
external_ca_providers:

  none:
    display_name: "None"
    integration_type: none
    requires_api_credentials: false
    description: "No external CA integration"
    capabilities:
      issue: false
      renew: false
      revoke: false
      discover: false
      inventory: false

  letsencrypt:
    display_name: "Let's Encrypt"
    integration_type: acme
    requires_api_credentials: false
    description: "Free ACME-based CA. Uses ACME v2 protocol."
    endpoints:
      production: "https://acme-v02.api.letsencrypt.org/directory"
      staging: "https://acme-staging-v02.api.letsencrypt.org/directory"
    capabilities:
      issue: true
      renew: true
      revoke: true
      discover: false
      inventory: false
    rate_limits:
      certificates_per_domain_per_week: 50
      duplicate_certificates_per_week: 5
      failed_validations_per_account_per_hour: 5
    notes:
      - "No API credentials required"
      - "Rate limits apply — use staging for testing"
      - "90-day certificate lifetime"
      - "Wildcard supported via DNS-01"

  digicert:
    display_name: "DigiCert"
    integration_type: anyca
    requires_api_credentials: true
    description: "Enterprise CA. Uses REST AnyCA gateway or native API."
    endpoints:
      production: "https://www.digicert.com/services/v2"
    capabilities:
      issue: true
      renew: true
      revoke: true
      discover: true
      inventory: true
    credential_requirements:
      - name: "api_key"
        description: "DigiCert API key"
        secret_ref: "digicert/api-key"
      - name: "account_id"
        description: "DigiCert account ID"
        secret_ref: "digicert/account-id"
    notes:
      - "Requires API credentials"
      - "Supports OV, EV, DV certificates"
      - "Enterprise support available"

  sectigo:
    display_name: "Sectigo"
    integration_type: anyca
    requires_api_credentials: true
    description: "Commercial CA. Uses REST AnyCA gateway or native API."
    endpoints:
      production: "https://api.sectigo.com/v1"
    capabilities:
      issue: true
      renew: true
      revoke: true
      discover: true
      inventory: true
    credential_requirements:
      - name: "api_key"
        description: "Sectigo API key"
        secret_ref: "sectigo/api-key"
      - name: "account_id"
        description: "Sectigo account ID"
        secret_ref: "sectigo/account-id"
    notes:
      - "Requires API credentials"
      - "Supports OV, EV, DV certificates"

  globalsign:
    display_name: "GlobalSign"
    integration_type: anyca
    requires_api_credentials: true
    description: "Enterprise CA. Uses REST AnyCA gateway or native API."
    endpoints:
      production: "https://api.globalsign.com/v1"
    capabilities:
      issue: true
      renew: true
      revoke: true
      discover: true
      inventory: true
    credential_requirements:
      - name: "api_key"
        description: "GlobalSign API key"
        secret_ref: "globalsign/api-key"
      - name: "account_id"
        description: "GlobalSign account ID"
        secret_ref: "globalsign/account-id"
    notes:
      - "Requires API credentials"
      - "Enterprise support available"

  entrust:
    display_name: "Entrust"
    integration_type: anyca
    requires_api_credentials: true
    description: "Enterprise CA. Uses REST AnyCA gateway or native API."
    endpoints:
      production: "https://api.entrust.com/v1"
    capabilities:
      issue: true
      renew: true
      revoke: true
      discover: true
      inventory: true
    credential_requirements:
      - name: "api_key"
        description: "Entrust API key"
        secret_ref: "entrust/api-key"
      - name: "account_id"
        description: "Entrust account ID"
        secret_ref: "entrust/account-id"
    notes:
      - "Requires API credentials"
      - "Enterprise support available"

  godaddy:
    display_name: "GoDaddy"
    integration_type: custom
    requires_api_credentials: true
    description: "Commercial CA. Uses custom adapter for GoDaddy API."
    endpoints:
      production: "https://api.godaddy.com/v1"
    capabilities:
      issue: true
      renew: true
      revoke: true
      discover: false
      inventory: false
    credential_requirements:
      - name: "api_key"
        description: "GoDaddy API key"
        secret_ref: "godaddy/api-key"
      - name: "api_secret"
        description: "GoDaddy API secret"
        secret_ref: "godaddy/api-secret"
    notes:
      - "Requires API credentials"
      - "Custom adapter required"
      - "Limited API capabilities"

  custom:
    display_name: "Custom / Other"
    integration_type: custom
    requires_api_credentials: true
    description: "Custom CA integration. Configurable adapter."
    endpoints: {}
    capabilities:
      issue: true
      renew: true
      revoke: true
      discover: false
      inventory: false
    credential_requirements:
      - name: "api_key"
        description: "Custom CA API key"
        secret_ref: "custom/api-key"
    notes:
      - "Requires custom adapter implementation"
      - "Endpoint configuration required"
      - "Capabilities depend on implementation"
```

---

## CA Abstraction Interface

All external CA adapters must implement the following normalized operations where supported:

```yaml
operations:
  request:
    description: "Submit a certificate request"
    required: true
    input: "CertificateRequest (CN, SANs, validity, key_type)"
    output: "RequestID"

  issue:
    description: "Issue a certificate from an approved request"
    required: true
    input: "RequestID"
    output: "Certificate (PEM)"

  renew:
    description: "Renew an existing certificate"
    required: false
    input: "CertificateSerialNumber"
    output: "Certificate (PEM)"

  revoke:
    description: "Revoke a certificate"
    required: false
    input: "CertificateSerialNumber, Reason"
    output: "RevocationStatus"

  status:
    description: "Get certificate/request status"
    required: true
    input: "RequestID or CertificateSerialNumber"
    output: "Status"

  retrieve:
    description: "Retrieve an issued certificate"
    required: true
    input: "RequestID or CertificateSerialNumber"
    output: "Certificate (PEM)"

  discover:
    description: "Discover existing certificates (optional)"
    required: false
    input: "Filter criteria"
    output: "CertificateList"

  inventory:
    description: "Get certificate inventory (optional)"
    required: false
    input: "None"
    output: "InventoryReport"
```

---

## Deployment Modes by Tier

### Economy

```yaml
deployment:
  mode: container
  replicas: 1
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi
  persistence: none
  monitoring: basic
  ha: false
```

### Standard

```yaml
deployment:
  mode: container
  replicas: 2
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 512Mi
  persistence: config
  monitoring: full
  ha: false
```

### Enterprise

```yaml
deployment:
  mode: container
  replicas: 3
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 2000m
      memory: 1Gi
  persistence: config
  monitoring: full
  ha: true
  load_balancing: true
  audit_logging: enhanced
```

---

## Secrets Management

External CA credentials must NEVER be stored in:
- Git
- Customer YAML
- Terraform tfvars
- Pipeline YAML
- Shell scripts
- Kubernetes ConfigMaps

**Approved secret stores by provider:**

| Cloud Provider | Secret Store | Access Method |
|---------------|-------------|---------------|
| Azure | Key Vault | Managed Identity |
| AWS | Secrets Manager | IAM Role / Instance Profile |
| Alibaba Cloud | Secrets Manager | RAM Role |
| Homelab | OpenBao | SPIFFE / Kubernetes SA |

---

## Validation Status

| Provider | Integration Type | Static Validation | Plan Validation | Live Validation | Notes |
|----------|-----------------|-------------------|-----------------|-----------------|-------|
| Let's Encrypt | ACME | ✅ | ⬜ | ⬜ | No credentials needed |
| DigiCert | AnyCA | ✅ | ⬜ | ⬜ | Credentials required |
| Sectigo | AnyCA | ✅ | ⬜ | ⬜ | Credentials required |
| GlobalSign | AnyCA | ✅ | ⬜ | ⬜ | Credentials required |
| Entrust | AnyCA | ✅ | ⬜ | ⬜ | Credentials required |
| GoDaddy | Custom | ✅ | ⬜ | ⬜ | Custom adapter needed |
| Custom | Custom | ✅ | ⬜ | ⬜ | Implementation dependent |

**Legend:** ✅ Complete | ⬜ Not started | ❌ Failed | ⚠️ Partial

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Master Orchestrator | Initial external CA adapter registry |
