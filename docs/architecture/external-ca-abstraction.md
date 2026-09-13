# External CA Integration Abstraction

## Overview

This document defines the **provider-neutral external CA integration abstraction** for the Machine Identity Platform. The abstraction layer enables the platform to integrate with multiple Certificate Authority backends without changing application code or customer configuration.

**Core Principle:** The platform speaks a **unified CA protocol** internally. External CAs are **adapters** that translate the unified protocol into vendor-specific APIs.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CERTIFICATE LIFECYCLE                                │
│                         (Unified Internal Protocol)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Request   │  │   Validate  │  │   Issue     │  │   Revoke    │        │
│  │   (CSR +    │  │   (Policy + │  │   (Sign +   │  │   (CRL +    │        │
│  │   Metadata) │  │   Schema)   │  │   Deliver)  │  │   OCSP)     │        │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘        │
│         │                │                │                │               │
│         └────────────────┴────────────────┴────────────────┘               │
│                          │                                                 │
│                          ▼                                                 │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                    CA ABSTRACTION LAYER (ca-service)                 │  │
│  │                                                                      │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │  │
│  │  │   Router    │  │   Policy    │  │   Audit     │  │   Cache   │  │  │
│  │  │   (Select   │  │   Engine    │  │   Logger    │  │   (Cert   │  │  │
│  │  │   Provider) │  │   (Rules)   │  │   (Events)  │  │   Status) │  │  │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────┬─────┘  │  │
│  │         │                │                │               │        │  │
│  │         └────────────────┴────────────────┴───────────────┘        │  │
│  │                          │                                         │  │
│  │                          ▼                                         │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │                    PROVIDER ADAPTERS                         │  │  │
│  │  │                                                              │  │  │
│  │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌───────┐ │  │  │
│  │  │  │  EJBCA  │ │  cert-  │ │ OpenBao │ │  AWS    │ │ Azure │ │  │  │
│  │  │  │ Adapter │ │ manager │ │   PKI   │ │  PCA    │ │  KV   │ │  │  │
│  │  │  │         │ │ Adapter │ │ Adapter │ │ Adapter │ │Adapter│ │  │  │
│  │  │  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └───┬───┘ │  │  │
│  │  │       │           │           │           │          │     │  │  │
│  │  └───────┼───────────┼───────────┼───────────┼──────────┼─────┘  │  │
│  │          │           │           │           │          │        │  │
│  │          ▼           ▼           ▼           ▼          ▼        │  │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐   │  │
│  │  │  EJBCA  │ │ cert-   │ │ OpenBao │ │  AWS    │ │ Azure   │   │  │
│  │  │  (EST/  │ │ manager │ │   PKI   │ │  PCA    │ │ Key     │   │  │
│  │  │  REST/  │ │ (K8s    │ │ (Vault  │ │ (ACM    │ │ Vault   │   │  │
│  │  │  SOAP)  │ │  CRD)   │ │  API)   │ │  PCA)   │ │ (REST)  │   │  │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘   │  │
│  │                                                                  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Unified CA Protocol

### Core Operations

All CA providers must implement these operations:

| Operation | Description | Input | Output |
|-----------|-------------|-------|--------|
| `issue_certificate` | Issue a new certificate | CSR + profile + metadata | Certificate + chain + serial |
| `renew_certificate` | Renew an existing certificate | Serial + new CSR (optional) | New certificate + chain |
| `revoke_certificate` | Revoke a certificate | Serial + reason | Revocation confirmation |
| `get_certificate` | Retrieve a certificate | Serial | Certificate + chain + status |
| `get_crl` | Get current CRL | CA identifier | CRL (DER or PEM) |
| `check_ocsp` | Check certificate status | Serial or CertID | OCSP response (good/revoked/unknown) |
| `get_ca_certificate` | Get CA certificate | CA identifier | CA certificate + chain |
| `list_certificates` | List certificates (paginated) | Filter + pagination | Certificate list |
| `health_check` | Check provider health | — | Health status |

### Certificate Request Schema

```json
{
  "request_id": "uuid",
  "profile": "tls-server",
  "subject": {
    "common_name": "server.example.com",
    "organization": "Example Corp",
    "organizational_unit": "IT",
    "locality": "Dallas",
    "state": "Texas",
    "country": "US"
  },
  "sans": {
    "dns": ["server.example.com", "www.example.com"],
    "ip": ["10.0.0.1"],
    "uri": ["spiffe://example.com/ns/default/sa/server"],
    "email": ["admin@example.com"]
  },
  "key": {
    "type": "ec",
    "curve": "p256",
    "size": null
  },
  "validity": {
    "days": 90,
    "not_before": null,
    "not_after": null
  },
  "extensions": {
    "key_usage": ["digitalSignature", "keyEncipherment"],
    "extended_key_usage": ["serverAuth", "clientAuth"],
    "basic_constraints": {"ca": false},
    "custom": {}
  },
  "csr": "-----BEGIN CERTIFICATE REQUEST-----\n...",
  "metadata": {
    "requester": "spiffe://example.com/ns/default/sa/client",
    "purpose": "web-server-tls",
    "environment": "production",
    "cost_center": "it-001"
  }
}
```

### Certificate Response Schema

```json
{
  "request_id": "uuid",
  "serial_number": "04:5c:7b:2a:1f:9e:3d:8c:7a:4e:2b:5f:1c:8d:3e:7a",
  "status": "issued",
  "certificate": "-----BEGIN CERTIFICATE-----\n...",
  "chain": [
    "-----BEGIN CERTIFICATE-----\n...",
    "-----BEGIN CERTIFICATE-----\n..."
  ],
  "ca_name": "ExampleIssuingCA",
  "profile": "tls-server",
  "not_before": "2026-09-12T00:00:00Z",
  "not_after": "2026-12-11T00:00:00Z",
  "issued_at": "2026-09-12T12:00:00Z",
  "metadata": {
    "provider": "ejbca",
    "provider_request_id": "ejbca-12345",
    "enrollment_protocol": "est"
  }
}
```

### Revocation Request Schema

```json
{
  "serial_number": "04:5c:7b:2a:1f:9e:3d:8c:7a:4e:2b:5f:1c:8d:3e:7a",
  "reason": "keyCompromise",
  "reason_code": 1,
  "revoked_by": "admin@example.com",
  "effective_date": "2026-09-12T12:00:00Z",
  "metadata": {
    "incident_id": "INC-001",
    "approved_by": "security-team@example.com"
  }
}
```

---

## Provider Adapters

### 1. EJBCA Adapter

**Status:** ✅ Implemented (current lab)

**Protocols:** EST, REST, SOAP

**Configuration:**
```yaml
provider:
  type: ejbca
  name: ejbca-primary
  url: https://ejbca.ejbca.svc
  auth:
    type: client_cert
    cert_secret: ejbca-api-credentials
    key_secret: ejbca-api-credentials
  cas:
    - name: LabIssuingCA
      profiles: [tls-server, tls-client, code-signing]
      default: true
    - name: LabRootCA
      profiles: [root-ca]
      default: false
  protocols:
    est:
      enabled: true
      endpoint: /.well-known/est
    rest:
      enabled: true
      endpoint: /ejbca/ejbcaws/ejbcaws
    scep:
      enabled: true
      endpoint: /ejbca/publicweb/apply/scep
    acme:
      enabled: true
      endpoint: /ejbca/acme
```

**Capabilities:**
| Capability | Supported | Notes |
|------------|-----------|-------|
| Issue certificate | ✅ | EST, REST |
| Renew certificate | ✅ | EST simplereenroll |
| Revoke certificate | ✅ | REST, CLI |
| Get certificate | ✅ | REST |
| CRL | ✅ | HTTP distribution |
| OCSP | ✅ | Built-in responder |
| SCEP | ✅ | Legacy support |
| ACME | ✅ | RFC 8555 |
| CMP | ✅ | Enterprise protocol |
| Key generation | ✅ | Server-side or client-side |
| HSM support | ✅ | PKCS#11 |

---

### 2. cert-manager Adapter

**Status:** ✅ Implemented (current lab)

**Protocols:** Kubernetes CRD

**Configuration:**
```yaml
provider:
  type: cert-manager
  name: cert-manager-internal
  cluster_issuers:
    - name: selfsigned-issuer
      type: selfsigned
      default: false
    - name: ca-issuer
      type: ca
      secret_name: ca-key-pair
      default: true
    - name: vault-issuer
      type: vault
      vault_url: https://openbao.openbao.svc:8200
      default: false
  namespaces:
    - default
    - pki
```

**Capabilities:**
| Capability | Supported | Notes |
|------------|-----------|-------|
| Issue certificate | ✅ | Certificate CRD |
| Renew certificate | ✅ | Automatic renewal |
| Revoke certificate | ⚠️ | Delete Certificate (no CRL) |
| Get certificate | ✅ | Secret read |
| CRL | ❌ | Not supported |
| OCSP | ❌ | Not supported |
| SCEP | ❌ | Not supported |
| ACME | ✅ | ACME issuer |
| CMP | ❌ | Not supported |
| Key generation | ✅ | Server-side |
| HSM support | ❌ | Not directly |

---

### 3. OpenBao PKI Adapter

**Status:** ✅ Implemented (current lab)

**Protocols:** Vault API (HTTP)

**Configuration:**
```yaml
provider:
  type: openbao-pki
  name: openbao-internal
  url: https://openbao.openbao.svc:8200
  auth:
    type: kubernetes
    role: pki-issuer
    mount: kubernetes
  mounts:
    - path: pki
      roles:
        - name: internal-tls
          ttl: 720h
          max_ttl: 8760h
          allowed_domains: ["example.com", "svc.cluster.local"]
          default: true
        - name: short-lived
          ttl: 24h
          max_ttl: 168h
          allowed_domains: ["internal.example.com"]
          default: false
```

**Capabilities:**
| Capability | Supported | Notes |
|------------|-----------|-------|
| Issue certificate | ✅ | PKI secrets engine |
| Renew certificate | ✅ | Re-issue with same role |
| Revoke certificate | ✅ | PKI revoke |
| Get certificate | ✅ | PKI read |
| CRL | ✅ | PKI CRL endpoint |
| OCSP | ❌ | Not built-in |
| SCEP | ❌ | Not supported |
| ACME | ❌ | Not supported |
| CMP | ❌ | Not supported |
| Key generation | ✅ | Server-side |
| HSM support | ✅ | Via seal/unseal |

---

### 4. AWS Private CA Adapter

**Status:** 📋 Documented (future)

**Protocols:** AWS API (ACM PCA)

**Configuration:**
```yaml
provider:
  type: aws-pca
  name: aws-pca-primary
  region: us-east-1
  auth:
    type: iam
    role_arn: arn:aws:iam::123456789012:role/pki-platform
  ca_arn: arn:aws:acm-pca:us-east-1:123456789012:certificate-authority/12345678-1234-1234-1234-123456789012
  templates:
    - name: tls-server
      template_arn: arn:aws:acm-pca:::template/EndEntityCertificate/V1
      default: true
```

**Capabilities:**
| Capability | Supported | Notes |
|------------|-----------|-------|
| Issue certificate | ✅ | IssueCertificate API |
| Renew certificate | ✅ | IssueCertificate (new serial) |
| Revoke certificate | ✅ | RevokeCertificate API |
| Get certificate | ✅ | GetCertificate API |
| CRL | ✅ | S3-based CRL |
| OCSP | ✅ | Managed OCSP |
| SCEP | ❌ | Not supported |
| ACME | ❌ | Not supported |
| CMP | ❌ | Not supported |
| Key generation | ✅ | Server-side |
| HSM support | ✅ | CloudHSM-backed |

---

### 5. Azure Key Vault Adapter

**Status:** 📋 Documented (future)

**Protocols:** Azure REST API

**Configuration:**
```yaml
provider:
  type: azure-keyvault
  name: azure-kv-primary
  vault_url: https://pki-vault.vault.azure.net
  auth:
    type: managed_identity
    client_id: 12345678-1234-1234-1234-123456789012
  certificates:
    - name: tls-server
      policy:
        key_type: RSA
        key_size: 2048
        validity_months: 12
        default: true
```

**Capabilities:**
| Capability | Supported | Notes |
|------------|-----------|-------|
| Issue certificate | ✅ | CreateCertificate API |
| Renew certificate | ✅ | UpdateCertificate API |
| Revoke certificate | ⚠️ | Delete (no CRL) |
| Get certificate | ✅ | GetCertificate API |
| CRL | ❌ | Not supported |
| OCSP | ❌ | Not supported |
| SCEP | ❌ | Not supported |
| ACME | ❌ | Not supported |
| CMP | ❌ | Not supported |
| Key generation | ✅ | Server-side |
| HSM support | ✅ | Managed HSM |

---

### 6. Smallstep CA Adapter

**Status:** 📋 Documented (future)

**Protocols:** ACME, SCEP, REST

**Configuration:**
```yaml
provider:
  type: smallstep
  name: step-ca-primary
  url: https://ca.smallstep.com
  auth:
    type: provisioner
    provisioner: admin
    key: /secrets/step-ca-key
  provisioners:
    - name: acme
      type: ACME
      default: true
    - name: scep
      type: SCEP
      default: false
```

**Capabilities:**
| Capability | Supported | Notes |
|------------|-----------|-------|
| Issue certificate | ✅ | ACME, REST |
| Renew certificate | ✅ | ACME renewal |
| Revoke certificate | ✅ | REST API |
| Get certificate | ✅ | REST API |
| CRL | ✅ | Built-in |
| OCSP | ✅ | Built-in |
| SCEP | ✅ | Built-in |
| ACME | ✅ | RFC 8555 |
| CMP | ❌ | Not supported |
| Key generation | ✅ | Server-side |
| HSM support | ✅ | PKCS#11, KMS |

---

## Provider Selection Logic

### Routing Rules

The ca-service routes requests to providers based on:

```python
def select_provider(request: CertificateRequest) -> CAProvider:
    # Rule 1: Profile-based routing
    if request.profile == "tls-server" and request.validity.days <= 90:
        return get_provider("ejbca-primary")
    
    # Rule 2: Short-lived certificates
    if request.validity.days <= 7:
        return get_provider("openbao-internal")
    
    # Rule 3: Kubernetes-internal certificates
    if request.metadata.get("kubernetes_service"):
        return get_provider("cert-manager-internal")
    
    # Rule 4: Cloud-native certificates
    if request.metadata.get("cloud_provider") == "aws":
        return get_provider("aws-pca-primary")
    
    # Rule 5: Default provider
    return get_provider("ejbca-primary")
```

### Routing Configuration

```yaml
routing:
  rules:
    - name: short-lived-certs
      condition:
        validity_days_lte: 7
      provider: openbao-internal
      priority: 100
    
    - name: k8s-internal
      condition:
        metadata_kubernetes_service: true
      provider: cert-manager-internal
      priority: 90
    
    - name: aws-cloud
      condition:
        metadata_cloud_provider: aws
      provider: aws-pca-primary
      priority: 80
    
    - name: default
      condition: {}
      provider: ejbca-primary
      priority: 0
  
  fallback:
    enabled: true
    order: [ejbca-primary, openbao-internal, cert-manager-internal]
```

---

## Failover and Redundancy

### Provider Health Checks

```yaml
health_checks:
  interval: 30s
  timeout: 10s
  unhealthy_threshold: 3
  healthy_threshold: 2
  
  providers:
    ejbca-primary:
      url: https://ejbca.ejbca.svc/ejbca/health
      method: GET
      expected_status: 200
    
    openbao-internal:
      url: https://openbao.openbao.svc:8200/v1/sys/health
      method: GET
      expected_status: 200
    
    cert-manager-internal:
      url: https://kubernetes.default.svc/apis/cert-manager.io/v1
      method: GET
      expected_status: 200
```

### Failover Behavior

| Scenario | Behavior |
|----------|----------|
| Primary provider unhealthy | Route to next healthy provider in fallback order |
| All providers unhealthy | Queue requests, alert operators, retry with backoff |
| Provider recovers | Resume routing to primary, drain queued requests |
| Partial failure (some CAs) | Route to healthy CAs within same provider |

---

## Tier-Specific CA Configuration

### ECONOMY Tier

| Aspect | Configuration |
|--------|---------------|
| **Providers** | EJBCA (primary), OpenBao PKI (short-lived) |
| **Failover** | None — single provider per type |
| **OCSP/CRL** | Single EJBCA responder |
| **HSM** | Not used |
| **External CAs** | Not configured |

### STANDARD Tier

| Aspect | Configuration |
|--------|---------------|
| **Providers** | EJBCA (primary), OpenBao PKI (short-lived), cert-manager (K8s) |
| **Failover** | EJBCA standby, OpenBao secondary |
| **OCSP/CRL** | 2 EJBCA responders (LB) |
| **HSM** | Optional (SoftHSM for testing) |
| **External CAs** | Optional (AWS PCA or Azure KV) |

### ENTERPRISE Tier

| Aspect | Configuration |
|--------|---------------|
| **Providers** | EJBCA (primary), OpenBao PKI (short-lived), cert-manager (K8s), AWS PCA (cloud), Azure KV (cloud) |
| **Failover** | Multi-provider, multi-region |
| **OCSP/CRL** | 3+ responders, global CDN |
| **HSM** | Required (CloudHSM, Dedicated HSM) |
| **External CAs** | Multiple (AWS PCA, Azure KV, GCP CAS) |

---

## Customer Intent Schema (schema_version: 2)

### Provider-Agnostic Configuration

```yaml
# customer-config.yaml
schema_version: 2

# Service tier — the ONLY infrastructure decision the customer makes
service_tier: standard  # economy | standard | enterprise

# Platform identity
platform:
  name: acme-pki
  environment: production
  trust_domain: acme.example.com

# Certificate profiles — what certificates the platform can issue
certificate_profiles:
  - name: tls-server
    description: TLS server certificates
    key_type: ec-p256
    validity_days: 90
    max_validity_days: 397
    key_usage: [digitalSignature, keyEncipherment]
    extended_key_usage: [serverAuth]
    san_types: [dns, ip]
    allowed_domains: ["*.example.com", "example.com"]
    
  - name: tls-client
    description: TLS client certificates
    key_type: ec-p256
    validity_days: 365
    key_usage: [digitalSignature]
    extended_key_usage: [clientAuth]
    san_types: [uri, email]
    
  - name: code-signing
    description: Code signing certificates
    key_type: rsa-4096
    validity_days: 365
    key_usage: [digitalSignature]
    extended_key_usage: [codeSigning]
    san_types: []

# CA configuration — which CAs to use, not how to deploy them
certificate_authorities:
  - name: primary-issuing
    type: external  # external | internal | cloud
    provider: ejbca  # ejbca | openbao | aws-pca | azure-kv | smallstep
    profiles: [tls-server, tls-client, code-signing]
    default: true
    
  - name: short-lived
    type: internal
    provider: openbao
    profiles: [tls-server]
    max_ttl_hours: 168
    
  - name: kubernetes
    type: internal
    provider: cert-manager
    profiles: [tls-server]

# External CA integrations — provider-specific details
external_ca_providers:
  - name: ejbca-primary
    type: ejbca
    url: https://ejbca.example.com
    auth:
      type: client_cert
      secret_ref: ejbca-api-credentials
    cas:
      - name: AcmeIssuingCA
        profiles: [tls-server, tls-client]
        
  - name: aws-pca-backup
    type: aws-pca
    region: us-east-1
    auth:
      type: iam
      role_arn: arn:aws:iam::123456789012:role/pki-platform
    ca_arn: arn:aws:acm-pca:us-east-1:123456789012:certificate-authority/...

# Observability — what to monitor, not how to deploy monitoring
observability:
  metrics:
    enabled: true
    retention_days: 30
  alerts:
    enabled: true
    channels: [email, slack]
    recipients:
      email: pki-alerts@example.com
      slack: "#pki-alerts"
  audit:
    enabled: true
    retention_days: 365
    siem_export: false  # enterprise only

# Backup — what to protect, not how to backup
backup:
  enabled: true
  retention_days: 30
  schedule: "0 2 * * *"  # daily at 2am
  targets:
    - type: s3
      bucket: acme-pki-backups
      region: us-east-1

# Compliance — what standards to meet, not how to implement
compliance:
  audit_logging: true
  encryption_at_rest: true
  encryption_in_transit: true
  fips_mode: false  # enterprise only
  soc2: false       # enterprise only
  pci_dss: false    # enterprise only
```

---

## Schema Translation

### Customer Intent → Platform Configuration

The platform translates `schema_version: 2` customer intent into tier-specific infrastructure:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CUSTOMER INTENT (schema_version: 2)                  │
│                                                                              │
│  service_tier: standard                                                      │
│  certificate_profiles: [tls-server, tls-client]                              │
│  certificate_authorities: [ejbca-primary, openbao-short-lived]               │
│  observability: {metrics: true, alerts: true}                                │
│  backup: {enabled: true, retention_days: 30}                                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TIER TRANSLATION ENGINE                              │
│                                                                              │
│  IF service_tier == "standard":                                              │
│    - node_count = 3                                                          │
│    - ha_model = active_passive                                               │
│    - storage = distributed                                                   │
│    - backup_frequency = daily                                                │
│    - monitoring = full_stack                                                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PROVIDER-SPECIFIC INFRASTRUCTURE                     │
│                                                                              │
│  Azure:                                                                      │
│    - 3x Standard_D4s_v5 VMs                                                  │
│    - Azure Disk CSI (Premium SSD)                                            │
│    - Azure Load Balancer                                                     │
│    - Azure Blob Storage (backup)                                             │
│                                                                              │
│  AWS:                                                                        │
│    - 3x m5.xlarge EC2 instances                                              │
│    - EBS CSI (gp3)                                                           │
│    - AWS NLB                                                                 │
│    - S3 (backup)                                                             │
│                                                                              │
│  Homelab:                                                                    │
│    - 3x libvirt VMs (4 vCPU, 16GB)                                           │
│    - Longhorn distributed storage                                            │
│    - MetalLB                                                                 │
│    - Local NFS (backup)                                                      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Platform Architect | Initial external CA abstraction |
