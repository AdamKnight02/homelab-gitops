# External CA Integration Architecture

## Overview

This document defines the external CA integration architecture for the Machine Identity Platform. External CA integration is provider-neutral, cloud-agnostic, and tier-aware.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CUSTOMER APPLICATION                                 │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CERTIFICATE API (cert-api)                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   REST API  │  │   AuthN     │  │   AuthZ     │  │  Validation │        │
│  │   (FastAPI) │  │ (SPIFFE/    │  │ (OpenBao    │  │  (Schema/   │        │
│  │             │  │  K8s SA)    │  │  policies)  │  │   Policy)   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │ AMQP 0-9-1
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          RABBITMQ MESSAGE QUEUE                              │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      CERTIFICATE WORKER (cert-worker)                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Consumer  │  │   Policy    │  │   CA Abstr  │  │   Notifier  │        │
│  │   (Pika)    │  │   Engine    │  │   Layer     │  │  (Events)   │        │
│  │             │  │             │  │             │  │             │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     CA ABSTRACTION LAYER (ca-service)                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   EJBCA     │  │   External  │  │   cert-     │  │   OpenBao   │        │
│  │   Adapter   │  │   CA        │  │   manager   │  │   PKI       │        │
│  │             │  │   Adapter   │  │   Adapter   │  │   Adapter   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│     EJBCA       │ │  External CA    │ │  cert-manager   │
│   (internal)    │ │   Gateway       │ │   (K8s certs)   │
│                 │ │                 │ │                 │
│  Root CA        │ │  DigiCert       │ │  TLS certs      │
│  Issuing CA     │ │  Sectigo        │ │  Ingress certs  │
│  OCSP           │ │  Let's Encrypt  │ │  Service certs  │
│  CRL            │ │  Custom         │ │                 │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

---

## External CA Gateway

### Deployment Modes

#### Containerized (Preferred)

```
Argo CD
   |
   v
External CA Integration
   |
   +---- DigiCert adapter (container)
   +---- Sectigo adapter (container)
   +---- ACME adapter (container)
```

**Requirements:**
- Gateway software must be containerizable
- Must support Kubernetes deployment
- Must support horizontal scaling (for HA)

#### VM-Based (Exception)

```
Terraform
   |
   v
Gateway VM
   |
   v
Configuration layer
```

**Requirements:**
- Gateway software requires dedicated VM
- Documented exception
- Single instance (no HA)

---

## Tier-Based Deployment

### Economy Tier

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
  network:
    inbound: none
    outbound: 443
```

### Standard Tier

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
  network:
    inbound: none
    outbound: 443
```

### Enterprise Tier

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
  network:
    inbound: none
    outbound: 443
```

---

## CA Abstraction Interface

### Normalized Operations

```yaml
operations:
  request:
    description: "Submit a certificate request"
    input: "CertificateRequest (CN, SANs, validity, key_type)"
    output: "RequestID"
    required: true

  issue:
    description: "Issue a certificate from an approved request"
    input: "RequestID"
    output: "Certificate (PEM)"
    required: true

  renew:
    description: "Renew an existing certificate"
    input: "CertificateSerialNumber"
    output: "Certificate (PEM)"
    required: false

  revoke:
    description: "Revoke a certificate"
    input: "CertificateSerialNumber, Reason"
    output: "RevocationStatus"
    required: false

  status:
    description: "Get certificate/request status"
    input: "RequestID or CertificateSerialNumber"
    output: "Status"
    required: true

  retrieve:
    description: "Retrieve an issued certificate"
    input: "RequestID or CertificateSerialNumber"
    output: "Certificate (PEM)"
    required: true

  discover:
    description: "Discover existing certificates (optional)"
    input: "Filter criteria"
    output: "CertificateList"
    required: false

  inventory:
    description: "Get certificate inventory (optional)"
    input: "None"
    output: "InventoryReport"
    required: false
```

### Capability Metadata

```yaml
capabilities:
  letsencrypt:
    issue: true
    renew: true
    revoke: true
    discover: false
    inventory: false

  digicert:
    issue: true
    renew: true
    revoke: true
    discover: true
    inventory: true

  sectigo:
    issue: true
    renew: true
    revoke: true
    discover: true
    inventory: true

  custom:
    issue: true
    renew: true
    revoke: true
    discover: false
    inventory: false
```

---

## Secrets Management

### Credential Storage

| Provider | Credential Type | Storage | Access Method |
|----------|---------------|---------|---------------|
| DigiCert | API Key | Cloud secret store | Workload identity |
| Sectigo | API Key | Cloud secret store | Workload identity |
| Let's Encrypt | None (ACME) | N/A | N/A |
| Custom | API Key | Cloud secret store | Workload identity |

### Cloud Secret Stores

| Cloud Provider | Secret Store | Access Method |
|---------------|-------------|---------------|
| Azure | Key Vault | Managed Identity |
| AWS | Secrets Manager | IAM Role / Instance Profile |
| Alibaba | Secrets Manager | RAM Role |
| Homelab | OpenBao | SPIFFE / Kubernetes SA |

### Rules

- NEVER store credentials in Git, customer YAML, Terraform tfvars, pipeline YAML, shell scripts, or ConfigMaps
- ALWAYS use workload identity to retrieve credentials
- NEVER print credentials in logs or pipeline output

---

## Network Security

### Requirements

| Requirement | Implementation |
|-------------|----------------|
| No public inbound | Default deny inbound |
| Outbound only | Gateway → External CA API (443) |
| TLS required | TLS 1.3 for all external CA traffic |
| DNS resolution | Internal DNS or approved external DNS |

### Network Policy

```yaml
# gitops/external-ca-gateway/base/networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: external-ca-gateway
  namespace: pki
spec:
  podSelector:
    matchLabels:
      app: external-ca-gateway
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 53  # DNS
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
      ports:
        - protocol: TCP
          port: 443  # HTTPS to external CA
```

---

## Monitoring

### Metrics

| Metric | Type | Description | Source |
|--------|------|-------------|--------|
| `external_ca_gateway_up` | Gauge | Gateway availability | Blackbox probe |
| `external_ca_api_reachable` | Gauge | External CA API reachability | Blackbox probe |
| `external_ca_requests_total` | Counter | Total requests | External CA gateway |
| `external_ca_issuance_total` | Counter | Total issuance | External CA gateway |
| `external_ca_issuance_failures_total` | Counter | Issuance failures | External CA gateway |
| `external_ca_renewal_failures_total` | Counter | Renewal failures | External CA gateway |
| `external_ca_revocation_failures_total` | Counter | Revocation failures | External CA gateway |
| `external_ca_api_latency_seconds` | Histogram | API latency | External CA gateway |
| `external_ca_auth_failures_total` | Counter | Authentication failures | External CA gateway |
| `external_ca_rate_limit_total` | Counter | Rate limit responses | External CA gateway |
| `external_ca_issuance_duration_seconds` | Histogram | Issuance duration | External CA gateway |

### Dashboard

**External CA Integrations**

Panels:
- Provider Status (DigiCert, Sectigo, Let's Encrypt, etc.)
- Requests per minute
- Success rate
- Failure rate
- Latency
- Rate limits
- Authentication failures

---

## Smoke Tests

### Connectivity Tests

| Test | Description | Tool |
|------|-------------|------|
| DNS resolution | Resolve external CA API hostname | dig/nslookup |
| TCP connectivity | Connect to external CA API port 443 | nc/telnet |
| TLS handshake | Perform TLS handshake | openssl s_client |
| API endpoint availability | Check API endpoint responds | curl |

### Authentication Tests

| Test | Description | Tool |
|------|-------------|------|
| Credential validation | Validate credentials without printing | API call |
| Permission check | Check credential has required permissions | API call |

### PKI Tests

| Test | Description | Safety |
|------|-------------|--------|
| Request test certificate | Request a test certificate | Test profile |
| Verify issuer | Verify certificate issuer | Test profile |
| Verify chain | Verify certificate chain | Test profile |
| Verify SAN | Verify certificate SANs | Test profile |
| Verify expiration | Verify certificate expiration | Test profile |
| Verify inventory entry | Verify certificate in inventory | Test profile |
| Revoke test certificate | Revoke test certificate | Test profile |
| Verify revocation | Verify certificate is revoked | Test profile |

**Safety Rules:**
- Use dedicated test profile, test account, test domain, test certificate
- Do NOT consume production issuance quotas unnecessarily
- Clean up test certificates after testing

---

## Add-On Removal

### Removal Flow

```
User selects:
  Customer: contoso
  Environment: prod
  Cloud: azure
  Add-On: External CA Integration
  Provider: DigiCert
  Operation: remove

Pipeline executes:
  1. Load current customer state
  2. Validate removal request
  3. Show dependencies
  4. Approval
  5. Terraform plan -destroy (external CA only)
  6. Terraform apply (destroy)
  7. Verify internal PKI unaffected
  8. Report
```

### Rules

- Do NOT automatically revoke certificates merely because a gateway is removed
- Do NOT destroy credentials or historical audit data without explicit policy
- Verify internal PKI is unaffected after removal

---

## Switching Providers

### Migration Flow

```
Current: DigiCert
Target: Sectigo

Steps:
  1. Deploy new Sectigo adapter
  2. Validate Sectigo connectivity
  3. Test issuance with Sectigo
  4. Update routing/policy to use Sectigo
  5. Observe
  6. Retire old DigiCert adapter
```

### Rules

- Never immediately replace an active CA integration
- Always validate new adapter before switching
- Always test issuance before switching
- Observe new adapter before retiring old one

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Master Orchestrator | Initial external CA integration architecture |
