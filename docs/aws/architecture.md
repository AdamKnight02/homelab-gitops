# AWS Architecture

## Overview

This document describes the AWS infrastructure architecture for the PKI Platform. The AWS provider supports three service tiers — **Economy**, **Standard**, and **Enterprise** — each mapping to a different infrastructure topology while using the same application code and GitOps workflows.

**Core Principle:** Tiers are intent declarations, not cloud SKUs. Set `service_tier = "standard"` and the platform translates that into the appropriate AWS resources.

---

## Architecture Diagrams

### Economy Tier (Default)

```
┌─────────────────────────────────────────────────────────┐
│                      AWS VPC                           │
│                   10.0.0.0/16                          │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │              Public Subnet                       │  │
│  │              10.0.1.0/24                         │  │
│  │                                                  │  │
│  │  ┌────────────────────────────────────────────┐  │  │
│  │  │           EC2 Instance (t3.micro)          │  │  │
│  │  │                                            │  │  │
│  │  │  ┌──────────────────────────────────────┐  │  │  │
│  │  │  │         K3s Single Node              │  │  │  │
│  │  │  │                                      │  │  │  │
│  │  │  │  ┌────────┐ ┌────────┐ ┌─────────┐ │  │  │  │
│  │  │  │  │cert-api│ │OpenBao │ │PostgreSQL│ │  │  │  │
│  │  │  │  │  (1)   │ │  (1)   │ │   (1)    │ │  │  │  │
│  │  │  │  └────────┘ └────────┘ └─────────┘ │  │  │  │
│  │  │  │  ┌────────┐ ┌────────┐ ┌─────────┐ │  │  │  │
│  │  │  │  │ EJBCA  │ │ SPIRE  │ │RabbitMQ │ │  │  │  │
│  │  │  │  │  (1)   │ │  (1)   │ │   (1)   │ │  │  │  │
│  │  │  │  └────────┘ └────────┘ └─────────┘ │  │  │  │
│  │  │  └──────────────────────────────────────┘  │  │  │
│  │  │                                            │  │  │
│  │  │  20 GB gp3 EBS (encrypted)                │  │  │
│  │  └────────────────────────────────────────────┘  │  │
│  │                                                  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  IGW ──► Internet                                       │
│  No NAT Gateway                                         │
│  No Load Balancer                                       │
│  No RDS                                                 │
│  No S3                                                  │
│  No KMS                                                 │
│                                                         │
│  Estimated Cost: ~$10-14/month                          │
└─────────────────────────────────────────────────────────┘
```

### Standard Tier

```
┌─────────────────────────────────────────────────────────┐
│                      AWS VPC                           │
│                   10.0.0.0/16                          │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │              Public Subnet (1 AZ)                │  │
│  │              10.0.1.0/24                         │  │
│  │                                                  │  │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────┐ │  │
│  │  │ EC2 (server) │ │ EC2 (agent)  │ │EC2(agent)│ │  │
│  │  │  t3.medium   │ │  t3.medium   │ │t3.medium │ │  │
│  │  │              │ │              │ │          │ │  │
│  │  │  K3s Server  │ │  K3s Agent   │ │K3s Agent │ │  │
│  │  │  OpenBao(1)  │ │  cert-api(1) │ │cert-api(1│ │  │
│  │  │  SPIRE(1)    │ │  EJBCA(act)  │ │EJBCA(stby│ │  │
│  │  │  RabbitMQ(1) │ │  RabbitMQ(1) │ │RabbitMQ(1│ │  │
│  │  │  50 GB gp3   │ │  50 GB gp3   │ │50 GB gp3 │ │  │
│  │  └──────────────┘ └──────────────┘ └──────────┘ │  │
│  │                                                  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │              RDS PostgreSQL                      │  │
│  │              db.t3.micro (single-AZ)             │  │
│  │              20 GB gp3, encrypted                │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │              S3 Bucket (backups)                 │  │
│  │              AES-256 encrypted                   │  │
│  │              30-day lifecycle                    │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │              NLB (Network Load Balancer)         │  │
│  │              Port 80, 443, 6443                  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  IGW ──► Internet                                       │
│  No NAT Gateway                                         │
│  No KMS                                                 │
│  No Secrets Manager                                     │
│                                                         │
│  Estimated Cost: ~$130/month                            │
└─────────────────────────────────────────────────────────┘
```

### Enterprise Tier

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS VPC                                 │
│                     10.0.0.0/16                                │
│                                                                 │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐  │
│  │   AZ-a          │ │   AZ-b          │ │   AZ-c          │  │
│  │                 │ │                 │ │                 │  │
│  │ ┌─────────────┐ │ │ ┌─────────────┐ │ │ ┌─────────────┐ │  │
│  │ │Public Subnet│ │ │ │Public Subnet│ │ │ │Public Subnet│ │  │
│  │ │10.0.1.0/24  │ │ │ │10.0.2.0/24  │ │ │ │10.0.3.0/24  │ │  │
│  │ │             │ │ │ │             │ │ │ │             │ │  │
│  │ │ EC2 (server)│ │ │ │ EC2 (agent) │ │ │ │ EC2 (agent) │ │  │
│  │ │ m6i.large   │ │ │ │ m6i.large   │ │ │ │ m6i.large   │ │  │
│  │ └─────────────┘ │ │ └─────────────┘ │ │ └─────────────┘ │  │
│  │                 │ │                 │ │                 │  │
│  │ ┌─────────────┐ │ │ ┌─────────────┐ │ │ ┌─────────────┐ │  │
│  │ │Private Subnet│ │ │ │Private Subnet│ │ │ │Private Subnet│ │  │
│  │ │10.0.101.0/24│ │ │ │10.0.102.0/24│ │ │ │10.0.103.0/24│ │  │
│  │ │             │ │ │ │             │ │ │ │             │ │  │
│  │ │ EC2 (server)│ │ │ │ EC2 (agent) │ │ │ │ EC2 (agent) │ │  │
│  │ │ m6i.large   │ │ │ │ m6i.large   │ │ │ │ m6i.large   │ │  │
│  │ └─────────────┘ │ │ └─────────────┘ │ │ └─────────────┘ │  │
│  │                 │ │                 │ │                 │  │
│  │ ┌─────────────┐ │ │ ┌─────────────┐ │ │ ┌─────────────┐ │  │
│  │ │NAT Gateway  │ │ │ │NAT Gateway  │ │ │ │NAT Gateway  │ │  │
│  │ └─────────────┘ │ │ └─────────────┘ │ │ └─────────────┘ │  │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              RDS PostgreSQL Multi-AZ                     │  │
│  │              db.r6g.large                                │  │
│  │              100 GB gp3, KMS encrypted                   │  │
│  │              30-day backup retention                     │  │
│  │              Performance Insights enabled                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              S3 Bucket (backups)                         │  │
│  │              KMS encrypted, versioned                    │  │
│  │              IA after 30d, Glacier after 90d             │  │
│  │              365-day retention                           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              NLB (Network Load Balancer)                 │  │
│  │              Cross-zone load balancing                   │  │
│  │              Deletion protection                         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              KMS Key (auto-rotating)                     │  │
│  │              Secrets Manager (DB creds, unseal keys)     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Estimated Cost: ~$650/month                                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Module Structure

```
infra/terraform/
├── aws/                              # Root module (entry point)
│   ├── main.tf                       # Tier-driven composition
│   ├── variables.tf                  # Input variables (including service_tier)
│   ├── locals.tf                     # Naming, tagging, cloud-init
│   ├── outputs.tf                    # Outputs (including cost guardrails)
│   ├── versions.tf                   # Provider constraints
│   ├── templates/
│   │   └── cloud-init.yaml.tpl       # Economy cloud-init template
│   └── terraform.tfvars.example      # Example variable values
│
└── modules/aws/                      # Shared modules
    ├── tier-config/                  # Central tier-to-resource mapping
    │   └── tier-config.tf
    ├── network/                      # VPC, subnets, IGW, NAT, route tables
    │   └── network.tf
    ├── security/                     # Security groups and rules
    │   └── security.tf
    ├── identity/                     # IAM roles, policies, instance profiles
    │   └── identity.tf
    ├── compute/                      # EC2 instances for K3s nodes
    │   └── compute.tf
    ├── storage/                      # S3 buckets, EBS configuration
    │   └── storage.tf
    ├── database/                     # RDS PostgreSQL
    │   └── database.tf
    ├── secrets/                      # KMS keys, Secrets Manager
    │   └── secrets.tf
    ├── load-balancer/                # NLB, target groups, listeners
    │   └── load-balancer.tf
    └── kubernetes-bootstrap/         # Cloud-init templates for K3s
        ├── kubernetes-bootstrap.tf
        └── templates/
            ├── cloud-init-server.yaml.tpl
            └── cloud-init-agent.yaml.tpl
```

---

## Module Dependency Graph

```
                    ┌──────────────┐
                    │ tier-config  │
                    │ (locals only)│
                    └──────┬───────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               ▼
    ┌────────────┐  ┌────────────┐  ┌────────────┐
    │  network   │  │  secrets   │  │  security  │
    │            │  │  (KMS/SM)  │  │            │
    └──────┬─────┘  └──────┬─────┘  └──────┬─────┘
           │               │               │
           │               ▼               │
           │        ┌────────────┐         │
           │        │  storage   │         │
           │        │  (S3)      │         │
           │        └──────┬─────┘         │
           │               │               │
           │               ▼               │
           │        ┌────────────┐         │
           │        │  identity  │◄────────┘
           │        │  (IAM)     │
           │        └──────┬─────┘
           │               │
           ▼               ▼
    ┌────────────┐  ┌────────────┐
    │  database  │  │kubernetes- │
    │  (RDS)     │  │bootstrap   │
    └──────┬─────┘  └──────┬─────┘
           │               │
           ▼               ▼
           │        ┌────────────┐
           │        │  compute   │
           │        │  (EC2)     │
           │        └──────┬─────┘
           │               │
           ▼               ▼
           │        ┌────────────┐
           └───────►│load-       │
                    │balancer    │
                    │(NLB)       │
                    └────────────┘
```

---

## Security Architecture

### Network Security

| Layer | Economy | Standard | Enterprise |
|-------|---------|----------|------------|
| **VPC** | Single VPC | Single VPC | Single VPC |
| **Subnets** | 1 public | 1 public | 3 public + 3 private |
| **NAT Gateway** | None | None | 3 (one per AZ) |
| **Security Groups** | 1 (K3s) | 3 (K3s, LB, RDS) | 3 (K3s, LB, RDS) |
| **SSH Access** | Optional (CIDR-restricted) | Optional (CIDR-restricted) | Optional (CIDR-restricted) |
| **NodePort Range** | VPC-only | VPC-only | VPC-only |
| **Inter-node** | N/A (single node) | Self-referencing SG | Self-referencing SG |

### IAM Security

| Policy | Economy | Standard | Enterprise |
|--------|---------|----------|------------|
| **SSM** | ✅ | ✅ | ✅ |
| **CloudWatch Read** | ✅ | ✅ | ✅ |
| **CloudWatch Agent** | ❌ | ✅ | ✅ |
| **S3 Access** | ❌ | ✅ | ✅ |
| **EBS CSI Driver** | ❌ | ✅ | ✅ |
| **KMS Access** | ❌ | ❌ | ✅ |
| **Secrets Manager** | ❌ | ❌ | ✅ |

### Encryption

| Layer | Economy | Standard | Enterprise |
|-------|---------|----------|------------|
| **EBS** | AES-256 (default) | AES-256 (default) | KMS (customer-managed) |
| **S3** | N/A | AES-256 | KMS (customer-managed) |
| **RDS** | N/A | AES-256 (default) | KMS (customer-managed) |
| **Secrets Manager** | N/A | N/A | KMS (customer-managed) |

---

## Cost Guardrails

Before every `terraform apply`, review the `cost_guardrail_summary` output:

```
=== COST GUARDRAIL SUMMARY (ECONOMY tier) ===
EC2 Instances:    1
EBS Volumes:      1 (20 GB)
NAT Gateways:     0
Public IPs:       0
RDS Instances:    0
EKS Clusters:     0
Load Balancers:   0
S3 Buckets:       0
KMS Keys:         0
Secrets Manager:  0

Estimated Monthly Cost: ~$10.10
==============================================
```

**Economy tier guarantees:**
- ❌ No NAT Gateway (would cost ~$32/month each)
- ❌ No RDS (would cost ~$15-60/month)
- ❌ No EKS (would cost ~$73/month)
- ❌ No Load Balancer (would cost ~$16/month)
- ❌ No S3, KMS, or Secrets Manager

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | AWS Provider Engineer | Initial AWS architecture document |
