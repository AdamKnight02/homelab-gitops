# Security Architecture

## Overview

This document defines the security architecture for the Machine Identity Platform. Security is layered, with controls at the network, identity, secrets, application, and data levels.

---

## Defense in Depth

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ LAYER 7: AUDIT & MONITORING                                                  │
│  Comprehensive logging, alerting, compliance reporting                       │
├─────────────────────────────────────────────────────────────────────────────┤
│ LAYER 6: DATA                                                                │
│  Encryption at rest, encryption in transit, key management                   │
├─────────────────────────────────────────────────────────────────────────────┤
│ LAYER 5: APPLICATION                                                         │
│  RBAC, OpenBao policies, certificate policies                                │
├─────────────────────────────────────────────────────────────────────────────┤
│ LAYER 4: IDENTITY                                                            │
│  SPIFFE/SPIRE workload identity, mTLS, cloud IAM/RAM                         │
├─────────────────────────────────────────────────────────────────────────────┤
│ LAYER 3: SECRETS                                                             │
│  OpenBao, cloud secret stores, HSM/KMS                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│ LAYER 2: NETWORK                                                             │
│  NetworkPolicy, Security Groups, NSGs, WAF                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│ LAYER 1: PERIMETER                                                           │
│  Load balancer, TLS termination, DDoS protection                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Identity & Access Management

### Cloud Provider Identity

| Provider | Identity Type | Use Case | Scope |
|----------|-------------|----------|-------|
| Azure | Managed Identity | VM identity for cloud resource access | Subscription |
| AWS | IAM Role / Instance Profile | EC2 identity for cloud resource access | Account |
| Alibaba | RAM Role | ECS identity for cloud resource access | Account |

### Workload Identity

| Component | Identity Type | Issuer | Use Case |
|-----------|-------------|--------|----------|
| cert-api | SPIFFE SVID | SPIRE | mTLS to RabbitMQ, OpenBao |
| cert-worker | SPIFFE SVID | SPIRE | mTLS to RabbitMQ, OpenBao |
| ca-service | SPIFFE SVID | SPIRE | mTLS to EJBCA, OpenBao |
| External CA Gateway | SPIFFE SVID | SPIRE | mTLS to OpenBao |

### Kubernetes RBAC

| Service Account | Namespace | Permissions |
|-----------------|-----------|-------------|
| cert-api | pki | Read/write cert-api config, read secrets |
| cert-worker | pki | Read/write cert-worker config, read secrets |
| ca-service | pki | Read/write ca-service config, read secrets |
| external-ca-gateway | pki | Read external-ca config, read secrets |
| prometheus | monitoring | Read metrics, read servicemonitors |
| grafana | monitoring | Read dashboards, read datasources |

---

## Secrets Management

### Secret Stores

| Store | Provider | Use Case | Access Method |
|-------|----------|----------|---------------|
| OpenBao | Cloud-neutral | Application secrets, CA keys | SPIFFE auth, Kubernetes SA |
| Key Vault | Azure | Cloud resource secrets | Managed Identity |
| Secrets Manager | AWS | Cloud resource secrets | IAM Role |
| Secrets Manager | Alibaba | Cloud resource secrets | RAM Role |

### Secret Classification

| Classification | Examples | Storage | Rotation |
|---------------|----------|---------|----------|
| **Critical** | Root CA private keys, HSM keys | HSM / OpenBao PKI | Manual ceremony |
| **High** | Issuing CA private keys, database passwords | OpenBao KV | Automated |
| **Medium** | API tokens, TLS certificates | OpenBao KV / cert-manager | Automated |
| **Low** | Configuration values | ConfigMaps | Manual |

### External CA Credentials

| Provider | Credential Type | Storage | Access Method |
|----------|---------------|---------|---------------|
| DigiCert | API Key | Cloud secret store | Workload identity |
| Sectigo | API Key | Cloud secret store | Workload identity |
| Let's Encrypt | None (ACME) | N/A | N/A |
| Custom | API Key | Cloud secret store | Workload identity |

**Rules:**
- NEVER store credentials in Git, customer YAML, Terraform tfvars, pipeline YAML, shell scripts, or ConfigMaps
- ALWAYS use workload identity to retrieve credentials
- NEVER print credentials in logs or pipeline output

---

## Network Security

### Network Policies

All namespaces implement:
- **Default deny** ingress/egress
- **Explicit allow** for required communications
- **Namespace-level** isolation

### Required Communications

| Source | Destination | Port | Protocol | Purpose |
|--------|-------------|------|----------|---------|
| cert-api | RabbitMQ | 5672 | AMQP | Message queue |
| cert-worker | RabbitMQ | 5672 | AMQP | Message queue |
| cert-api | OpenBao | 8200 | HTTPS | Secrets |
| cert-worker | OpenBao | 8200 | HTTPS | Secrets |
| ca-service | EJBCA | 443 | HTTPS | CA operations |
| ca-service | OpenBao | 8200 | HTTPS | Secrets |
| External CA Gateway | External CA API | 443 | HTTPS | External CA |
| Prometheus | All pods | 9100-9102 | HTTP | Metrics |
| Grafana | Prometheus | 9090 | HTTP | Dashboards |

### Cloud Network Security

| Provider | Control | Implementation |
|----------|---------|----------------|
| Azure | NSG | Default deny inbound, explicit allow |
| AWS | Security Group | Default deny inbound, explicit allow |
| Alibaba | Security Group | Default deny inbound, explicit allow |

---

## PKI Security

### CA Key Protection

| Key Type | Storage | Access | Backup |
|----------|---------|--------|--------|
| Root CA Private Key | HSM / Offline | Manual ceremony | Offline backup |
| Issuing CA Private Key | OpenBao PKI / HSM | EJBCA only | Encrypted backup |
| TLS Certificates | cert-manager / SPIRE | Automatic | N/A (short-lived) |

### Certificate Policy

| Policy | Enforcement | Scope |
|--------|-------------|-------|
| Key algorithm | RSA 2048+ / ECDSA P-256+ | All certificates |
| Validity period | Max 398 days | All certificates |
| SAN validation | DNS names only | All certificates |
| Revocation | OCSP + CRL | All certificates |

---

## Pipeline Security

### Authentication

| Pipeline | Auth Method | Scope |
|----------|-------------|-------|
| Azure DevOps | Service Connection (OIDC) | Subscription |
| GitHub Actions | OIDC / Service Principal | Repository |
| Argo CD | Kubernetes SA | Cluster |

### Authorization

| Stage | Approver | Criteria |
|-------|----------|----------|
| Plan | Automatic | Schema validation, cost guardrails |
| Approval | Security team | Cost, security review |
| Deploy | Automatic | Post-approval |
| Destroy | Security team | Explicit approval |

### State Security

| Control | Implementation |
|---------|----------------|
| State encryption | SSE (Azure Storage, S3, OSS) |
| State locking | Blob lease, DynamoDB, TableStore |
| State access | RBAC, IAM, RAM |
| State backup | Automated, encrypted |
| State in Git | NEVER |

---

## External CA Security

### Credential Validation

Before deploying an external CA integration:

```yaml
checks:
  - name: "Credential exists"
    query: "cloud secret store contains required credential"
    expected: "true"

  - name: "Credential not expired"
    query: "credential expiration date > now"
    expected: "true"

  - name: "Credential has required permissions"
    query: "credential can perform required operations"
    expected: "true"
```

### Network Security

| Requirement | Implementation |
|-------------|----------------|
| No public inbound | Default deny inbound |
| Outbound only | Gateway → External CA API (443) |
| TLS required | TLS 1.3 for all external CA traffic |
| DNS resolution | Internal DNS or approved external DNS |

---

## Compliance

### Audit Logging

| Event | Log Destination | Retention |
|-------|-----------------|-----------|
| Certificate issuance | PostgreSQL audit table | 7 years |
| Certificate revocation | PostgreSQL audit table | 7 years |
| CA key access | OpenBao audit log | 7 years |
| Secret access | OpenBao audit log | 1 year |
| Pipeline execution | Azure DevOps / GitHub | 1 year |

### Compliance Frameworks

| Framework | Applicability | Controls |
|-----------|-------------|----------|
| PCI DSS | If handling payment cards | Network segmentation, encryption, access control |
| HIPAA | If handling health data | Encryption, access control, audit logging |
| SOC 2 | General | Security, availability, confidentiality |
| ISO 27001 | General | Information security management |

---

## Security Review Checklist

### Pre-Deployment

- [ ] Customer config validated against schema v2
- [ ] No secrets in Git, tfvars, pipeline YAML, or ConfigMaps
- [ ] Network policies configured (default deny)
- [ ] RBAC configured (least privilege)
- [ ] Cloud IAM/RAM configured (least privilege)
- [ ] External CA credentials validated (if applicable)
- [ ] Cost guardrails configured
- [ ] State backend configured (encrypted, locked)

### Post-Deployment

- [ ] All pods running
- [ ] Network policies enforced
- [ ] mTLS working
- [ ] Secrets accessible via workload identity
- [ ] Audit logging enabled
- [ ] Monitoring alerts configured
- [ ] Backup configured
- [ ] External CA connectivity validated (if applicable)

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Master Orchestrator | Initial security architecture |
