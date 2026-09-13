# Multi-Cloud Platform Architecture

## Overview

This document defines the unified multi-cloud platform architecture for the Machine Identity Platform. The platform is designed to be **cloud-agnostic**, with provider-specific infrastructure remaining below the platform abstraction layer.

---

## Architectural Target

```
 GITHUB
 SOURCE OF TRUTH
 |
 +----------------+----------------+
 |                |                |
 v                v                v
 ADO           Argo CD          Agents
 Pipelines       |
 |               |
 v               v
 Terraform    PKI Platform
 |               |
 v               v
 Provider API   Kubernetes
 |               |
 +-----+---------+----------+
 |     |         |          |
 v     v         v          v
Azure AWS   Alibaba    Homelab
 |     |         |          |
 +-----+---------+----------+
       |
 CUSTOMER TIER
       |
 +-----+-----+--------+
 |     |     |        |
 v     v     v        v
ECONOMY STANDARD ENTERPRISE
```

---

## Layer Architecture

### Layer 1: Source of Truth (GitHub)

- **Repository:** `github.com/AdamKnight02/homelab-gitops`
- **Contains:** All Terraform, Kubernetes manifests, pipeline YAML, documentation
- **Branching:** `main` for production, feature branches for development
- **Protection:** Branch protection rules, required reviews, status checks

### Layer 2: Orchestration

| Component | Purpose | Scope |
|-----------|---------|-------|
| **Azure DevOps Pipelines** | Infrastructure deployment, customer onboarding | Cloud infrastructure |
| **Argo CD** | Application deployment, GitOps reconciliation | Kubernetes workloads |
| **Agents** | Configuration management, bootstrap | VM-level configuration |

### Layer 3: Infrastructure (Terraform)

| Provider | Root Module | Shared Modules | State Backend |
|----------|-------------|----------------|---------------|
| Azure | `infra/terraform/azure/` | `infra/terraform/modules/azure/` | Azure Storage |
| AWS | `infra/terraform/aws/` | `infra/terraform/modules/aws/` | S3 + DynamoDB |
| Alibaba | `infra/terraform/alibaba/` | `infra/terraform/modules/alibaba/` | OSS |
| Homelab | N/A (libvirt) | N/A | N/A |

### Layer 4: Platform (Kubernetes)

| Component | Purpose | Tier Availability |
|-----------|---------|-------------------|
| **K3s** | Kubernetes distribution | All tiers |
| **Argo CD** | GitOps controller | All tiers |
| **EJBCA** | Certificate Authority | All tiers |
| **OpenBao** | Secrets management | All tiers |
| **SPIRE** | Workload identity | All tiers |
| **RabbitMQ** | Message queue | All tiers |
| **cert-api** | Certificate REST API | All tiers |
| **cert-worker** | Certificate processing | All tiers |
| **ca-service** | CA abstraction | All tiers |
| **Prometheus** | Metrics collection | All tiers |
| **Grafana** | Dashboards | All tiers |

### Layer 5: Customer Tier

| Tier | Intent | Availability | Use Case |
|------|--------|--------------|----------|
| **ECONOMY** | Minimal viable PKI | 99.0% | Dev/test, POC |
| **STANDARD** | Production-ready | 99.9% | Production, SME |
| **ENTERPRISE** | High availability | 99.95% | Large enterprise |

---

## Provider Abstraction

### Design Principles

1. **Provider-specific concepts remain below the abstraction** — Customer configs never contain `azure_vm_size`, `aws_instance_type`, or `alibaba_instance_type`
2. **Tiers are intent, not SKUs** — `service_tier: standard` maps to provider-specific resources via tier maps
3. **Same application code everywhere** — Same container images, same GitOps workflows, same APIs
4. **Provider adapters implement contracts** — Each provider implements the same interface

### Provider Contract Interface

```hcl
# Abstract provider contract (implemented by each provider)
variable "cloud_provider" {
  type = string  # azure, aws, alibaba
}

variable "service_tier" {
  type = string  # economy, standard, enterprise
}

variable "customer_id" {
  type = string
}

variable "environment" {
  type = string  # lab, dev, staging, prod
}

# Outputs that every provider must produce
output "cluster_endpoint" { type = string }
output "cluster_ca_certificate" { type = string }
output "network_id" { type = string }
output "subnet_ids" { type = list(string) }
output "security_group_ids" { type = list(string) }
output "storage_class" { type = string }
output "load_balancer_ip" { type = string }
```

---

## Data Flow

### Certificate Issuance Flow

```
Customer Application
       |
       v
  cert-api (REST)
       |
       v
  RabbitMQ (AMQP)
       |
       v
  cert-worker
       |
       v
  ca-service (CA Abstraction)
       |
       +----------------+----------------+
       |                |                |
       v                v                v
    EJBCA         External CA      cert-manager
  (internal)      (DigiCert, etc)  (K8s certs)
       |                |                |
       v                v                v
  PostgreSQL      External API      K8s API
```

### Secrets Flow

```
OpenBao (Secrets Store)
       |
       +----------------+----------------+
       |                |                |
       v                v                v
  cert-api        cert-worker      ca-service
  (DB creds)      (API keys)       (CA creds)
       |                |                |
       v                v                v
  PostgreSQL      External CA      EJBCA
```

### Identity Flow

```
SPIRE Server
       |
       v
SPIRE Agent (DaemonSet)
       |
       v
Workload Pod (SVID)
       |
       v
mTLS to other services
```

---

## Network Architecture

### Economy Tier

```
Internet
   |
   v
[Public IP] (optional)
   |
   v
[VM: K3s single-node]
   |
   +-- Pod Network (10.42.0.0/24)
   +-- Service Network (10.43.0.0/16)
   +-- NodePort Services
```

### Standard Tier

```
Internet
   |
   v
[Load Balancer]
   |
   +----------------+----------------+
   |                |                |
   v                v                v
[VM: K3s server] [VM: K3s agent] [VM: K3s agent]
   |                |                |
   +----------------+----------------+
   |
   v
[Managed PostgreSQL] (optional)
```

### Enterprise Tier

```
Internet
   |
   v
[Load Balancer / WAF]
   |
   +----------------+----------------+----------------+
   |                |                |                |
   v                v                v                v
[VM: K3s server] [VM: K3s agent] [VM: K3s agent] [VM: K3s agent]
   |                |                |                |
   +----------------+----------------+----------------+
   |
   +----------------+----------------+
   |                |                |
   v                v                v
[HA PostgreSQL]  [Object Storage]  [HSM/KMS]
```

---

## Security Architecture

### Defense in Depth

| Layer | Control | Implementation |
|-------|---------|----------------|
| **Network** | Default deny | NetworkPolicy, Security Groups, NSGs |
| **Identity** | Workload identity | SPIFFE/SPIRE, mTLS |
| **Secrets** | Encrypted at rest | OpenBao, cloud KMS |
| **Application** | RBAC | Kubernetes RBAC, OpenBao policies |
| **Data** | Encryption in transit | TLS 1.3, mTLS |
| **Audit** | Comprehensive logging | Audit logs, Prometheus metrics |

### Trust Boundaries

| Boundary | Controls |
|----------|----------|
| Internet → Load Balancer | TLS termination, WAF (optional) |
| Load Balancer → K3s | NetworkPolicy, Security Groups |
| Pod → Pod | mTLS, NetworkPolicy |
| Pod → Database | mTLS, database auth |
| Pod → OpenBao | SPIFFE auth, OpenBao policies |
| Pod → External CA | TLS, API credentials |

---

## GitOps Structure

```
gitops/
├── base/                          # Cloud-neutral base
│   ├── namespace.yaml
│   ├── pki-database.yaml
│   ├── cert-api.yaml
│   ├── cert-worker.yaml
│   ├── ca-service.yaml
│   ├── rabbitmq.yaml
│   └── networkpolicy-default-deny.yaml
│
├── overlays/                      # Provider-specific overlays
│   ├── homelab/
│   │   ├── kustomization.yaml
│   │   ├── storage-class-patch.yaml
│   │   └── image-registry-patch.yaml
│   ├── azure/
│   │   ├── kustomization.yaml
│   │   ├── storage-class-patch.yaml
│   │   ├── image-registry-patch.yaml
│   │   └── trust-domain-patch.yaml
│   ├── aws/
│   │   ├── kustomization.yaml
│   │   ├── storage-class-patch.yaml
│   │   ├── image-registry-patch.yaml
│   │   └── trust-domain-patch.yaml
│   └── alibaba/
│       ├── kustomization.yaml
│       ├── storage-class-patch.yaml
│       ├── image-registry-patch.yaml
│       └── trust-domain-patch.yaml
│
├── tiers/                         # Tier-specific overlays
│   ├── economy/
│   │   ├── kustomization.yaml
│   │   ├── replicas-patch.yaml
│   │   └── resources-patch.yaml
│   ├── standard/
│   │   ├── kustomization.yaml
│   │   ├── replicas-patch.yaml
│   │   └── resources-patch.yaml
│   └── enterprise/
│       ├── kustomization.yaml
│       ├── replicas-patch.yaml
│       └── resources-patch.yaml
│
├── monitoring/                    # Monitoring stack
│   ├── base/
│   │   ├── prometheus/
│   │   ├── grafana/
│   │   ├── exporters/
│   │   ├── alerts/
│   │   └── dashboards/
│   └── overlays/
│       ├── economy/
│       ├── standard/
│       └── enterprise/
│
└── external-ca/                   # External CA integrations
    ├── base/
    │   ├── anyca-gateway/
    │   └── acme-client/
    └── overlays/
        ├── digicert/
        ├── sectigo/
        └── letsencrypt/
```

---

## State Management

### State Separation

```
terraform-state/
├── azure/
│   ├── contoso/
│   │   ├── prod/
│   │   │   ├── core/
│   │   │   │   └── terraform.tfstate
│   │   │   └── monitoring/
│   │   │       └── terraform.tfstate
│   │   └── staging/
│   │       └── core/
│   │           └── terraform.tfstate
│   └── fabrikam/
│       └── prod/
│           └── core/
│               └── terraform.tfstate
├── aws/
│   └── contoso/
│       └── prod/
│           └── core/
│               └── terraform.tfstate
└── alibaba/
    └── contoso/
        └── prod/
            └── core/
                └── terraform.tfstate
```

### Backend Configuration

| Provider | Backend | Locking | Encryption |
|----------|---------|---------|------------|
| Azure | Azure Storage | Blob lease | SSE |
| AWS | S3 | DynamoDB | SSE-S3/KMS |
| Alibaba | OSS | TableStore | SSE |

---

## Cross-Cloud Migration

### Migration Flow

```
Source Cloud (e.g., Azure)
       |
       v
[Inventory Current Environment]
       |
       v
[Export Provider-Neutral Customer Intent]
       |
       v
[Generate Target Plan (e.g., AWS)]
       |
       v
[Provision Target Environment]
       |
       v
[Deploy PKI Platform]
       |
       v
[Migrate Non-Sensitive Data/Config]
       |
       v
[PKI Migration Procedure]
       |
       v
[Run Full Smoke Tests]
       |
       v
[Compare Source/Target]
       |
       v
[Approval Gate]
       |
       v
[Traffic/DNS Cutover]
       |
       v
[Observe]
       |
       v
[Decommission Source]
```

### PKI Material Classification

| Classification | Description | Migration Method |
|---------------|-------------|------------------|
| **PORTABLE_CONFIG** | Configuration files, policies | GitOps sync |
| **PORTABLE_DATA** | Certificate inventory, audit logs | Database export/import |
| **REQUIRES_SECURE_MIGRATION** | CA certificates, CRLs | Secure transfer |
| **NON_EXPORTABLE_KEY_MATERIAL** | Root CA private keys, HSM keys | Manual ceremony |
| **REQUIRES_MANUAL_APPROVAL** | Issuing CA private keys | Approval gate + secure transfer |

---

## Cost Guardrails

### Pre-Apply Validation

Before every `terraform apply`, the pipeline must output:

```
==============================================
DEPLOYMENT PLAN VALIDATION
==============================================

Customer: contoso
Provider: azure
Tier: standard
Environment: prod
Region: eastus

EXPECTED RESOURCES:
- VMs: 3
- Cluster Nodes: 3
- Database Instances: 1
- Load Balancers: 1
- Public IPs: 1
- Storage Accounts: 1
- Managed Services: 1 (PostgreSQL)

ACTUAL PLAN RESOURCES:
- VMs: 3 ✓
- Cluster Nodes: 3 ✓
- Database Instances: 1 ✓
- Load Balancers: 1 ✓
- Public IPs: 1 ✓
- Storage Accounts: 1 ✓
- Managed Services: 1 ✓

COST ESTIMATE: ~$150/month

VALIDATION: PASS
```

### Hard Stops

| Tier | Unexpected Resource | Action |
|------|---------------------|--------|
| Economy | NAT Gateway, Managed K8s, RDS, ALB/NLB | STOP |
| Economy | >2 VMs, >1 Public IP | STOP |
| Standard | >5 VMs, >2 Load Balancers | STOP |
| Standard | Multi-region deployment | STOP |
| Enterprise | >10 VMs without approval | REVIEW |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Master Orchestrator | Initial multi-cloud platform architecture |
