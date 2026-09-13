# Alibaba Cloud Architecture

## Overview

This document describes the Alibaba Cloud infrastructure architecture for the Machine Identity Platform. It covers the Terraform module structure, resource topology, and design decisions specific to Alibaba Cloud.

**Status:** PLAN-ONLY — No Alibaba Cloud credentials are configured. All Terraform code is validated statically.

---

## Module Structure

```
infra/terraform/
├── alibaba/                          # Root module (entry point)
│   ├── main.tf                       # Tier-driven composition
│   ├── variables.tf                  # Input variables
│   ├── outputs.tf                    # Output values (incl. cost guardrails)
│   ├── locals.tf                     # Naming, tagging, derived config
│   ├── versions.tf                   # Provider constraints
│   └── templates/
│       └── cloud-init.yaml.tpl       # K3s + Argo CD bootstrap template
│
└── modules/alibaba/                  # Reusable modules
    ├── tier-config/                  # Central tier-to-resource mapping
    │   ├── main.tf                   # Tier definitions and cost report
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── versions.tf
    │
    ├── network/                      # VPC, VSwitch, NAT Gateway, EIP
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── versions.tf
    │
    ├── security/                     # Security Groups and Rules
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── versions.tf
    │
    ├── identity/                     # RAM Roles and Policy Attachments
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── versions.tf
    │
    ├── compute/                      # ECS Instances, Key Pairs, Disks
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── versions.tf
    │
    ├── storage/                      # OSS Buckets, NAS File Systems
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── versions.tf
    │
    ├── database/                     # ApsaraDB RDS PostgreSQL
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── versions.tf
    │
    ├── secrets/                      # KMS Keys, Secrets Manager
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── versions.tf
    │
    ├── load-balancer/                # SLB / NLB Load Balancers
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── versions.tf
    │
    ├── kubernetes-bootstrap/         # K3s + Argo CD Cloud-Init
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── versions.tf
    │   └── templates/
    │       └── cloud-init.yaml.tpl
    │
    └── monitoring-bootstrap/         # CloudMonitor, Prometheus, Grafana
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── versions.tf
```

---

## Resource Topology by Tier

### ECONOMY (Single Node)

```
┌─────────────────────────────────────────────────┐
│                  VPC (10.0.0.0/16)              │
│                                                 │
│  ┌───────────────────────────────────────────┐  │
│  │           VSwitch (10.0.1.0/24)           │  │
│  │                                           │  │
│  │  ┌─────────────────────────────────────┐  │  │
│  │  │         ECS Instance                │  │  │
│  │  │         ecs.t6-c1m2.large           │  │  │
│  │  │                                     │  │  │
│  │  │  ┌───────────────────────────────┐  │  │  │
│  │  │  │     K3s (single node)         │  │  │  │
│  │  │  │                               │  │  │  │
│  │  │  │  cert-api, cert-worker,       │  │  │  │
│  │  │  │  ca-service, EJBCA,           │  │  │  │
│  │  │  │  PostgreSQL, OpenBao,         │  │  │  │
│  │  │  │  SPIRE, RabbitMQ,             │  │  │  │
│  │  │  │  Prometheus, Grafana          │  │  │  │
│  │  │  └───────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  Security Group: deny all inbound except SSH    │
│  No NAT Gateway, No EIP, No Load Balancer       │
│  No RDS, No OSS, No KMS                         │
└─────────────────────────────────────────────────┘
```

### STANDARD (3-Node K3s)

```
┌─────────────────────────────────────────────────────────┐
│                  VPC (10.0.0.0/16)                      │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │              VSwitch (10.0.1.0/24)                │  │
│  │                                                   │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐        │  │
│  │  │  ECS-1   │  │  ECS-2   │  │  ECS-3   │        │  │
│  │  │ (Server) │  │ (Agent)  │  │ (Agent)  │        │  │
│  │  │          │  │          │  │          │        │  │
│  │  │ K3s      │  │ K3s      │  │ K3s      │        │  │
│  │  │ Control  │  │ Worker   │  │ Worker   │        │  │
│  │  └──────────┘  └──────────┘  └──────────┘        │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │     NLB     │  │  RDS (pg)    │  │  OSS Bucket   │  │
│  │  (internal) │  │  single-zone │  │  (versioning) │  │
│  └─────────────┘  └──────────────┘  └───────────────┘  │
│                                                         │
│  Security Group: SSH, K8s API, internal cluster         │
│  No NAT Gateway, No EIP, No KMS                         │
└─────────────────────────────────────────────────────────┘
```

### ENTERPRISE (6-Node Multi-Zone)

```
┌─────────────────────────────────────────────────────────────────┐
│                     VPC (10.0.0.0/16)                           │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                 VSwitch (10.0.1.0/24)                    │   │
│  │                                                          │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐               │   │
│  │  │  ECS-1   │  │  ECS-2   │  │  ECS-3   │  (Control)    │   │
│  │  │ Zone A   │  │ Zone B   │  │ Zone C   │               │   │
│  │  └──────────┘  └──────────┘  └──────────┘               │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐               │   │
│  │  │  ECS-4   │  │  ECS-5   │  │  ECS-6   │  (Workers)    │   │
│  │  │ Zone A   │  │ Zone B   │  │ Zone C   │               │   │
│  │  └──────────┘  └──────────┘  └──────────┘               │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────────┐   │
│  │   NLB    │  │RDS (HA)  │  │   OSS    │  │  KMS + SM     │   │
│  │(internet)│  │multi-zone│  │(versioned│  │               │   │
│  └──────────┘  └──────────┘  └──────────┘  └───────────────┘   │
│                                                                 │
│  ┌──────────┐  ┌──────────┐                                     │
│  │   NAT    │  │   EIP    │                                     │
│  │ Gateway  │  │          │                                     │
│  └──────────┘  └──────────┘                                     │
│                                                                 │
│  Security Group: SSH, K8s API, HTTP/S, internal cluster         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Alibaba Cloud Service Mapping

| Platform Need | Alibaba Cloud Service | Module |
|---------------|----------------------|--------|
| Virtual Network | VPC + VSwitch | `network` |
| Firewall | Security Groups | `security` |
| Identity & Access | RAM Roles | `identity` |
| Virtual Machines | ECS Instances | `compute` |
| Object Storage | OSS Buckets | `storage` |
| File Storage | NAS | `storage` |
| Relational Database | ApsaraDB RDS (PostgreSQL) | `database` |
| Key Management | KMS | `secrets` |
| Secrets Management | KMS Secrets | `secrets` |
| Load Balancer | NLB / SLB | `load-balancer` |
| Kubernetes | K3s on ECS (or ACK) | `kubernetes-bootstrap` |
| Monitoring | CloudMonitor + Prometheus | `monitoring-bootstrap` |
| NAT Gateway | NAT Gateway + EIP | `network` |

---

## Design Decisions

### 1. K3s over ACK (Default)

**Decision:** Use K3s on ECS instances instead of Alibaba Container Service for Kubernetes (ACK).

**Rationale:**
- ACK costs ~$70/month minimum (management fee)
- K3s provides full Kubernetes API compatibility
- Same GitOps workflows (Argo CD) work identically
- ACK is available as opt-in for enterprise tier via `var.enable_ack`

### 2. NLB over SLB (Standard/Enterprise)

**Decision:** Use Network Load Balancer (NLB) instead of classic Server Load Balancer (SLB).

**Rationale:**
- NLB provides higher performance (Layer 4)
- NLB supports anycast for multi-zone
- SLB is legacy; NLB is the recommended replacement
- SLB available as fallback via `var.slb_type = "slb"`

### 3. ApsaraDB RDS over Self-Managed PostgreSQL (Standard+)

**Decision:** Use ApsaraDB RDS PostgreSQL instead of containerized PostgreSQL for standard and enterprise tiers.

**Rationale:**
- Managed backups, patching, and monitoring
- Multi-zone HA available for enterprise
- Reduces operational burden
- Economy tier still uses containerized PostgreSQL

### 4. No NAT Gateway for Economy/Standard

**Decision:** NAT Gateway is only enabled for enterprise tier.

**Rationale:**
- NAT Gateway costs ~$30/month + data processing
- Economy/standard tiers use public IPs or direct internet access
- Enterprise tier uses private subnets requiring NAT for outbound

### 5. RAM Role Attachment via ECS Instance Attribute

**Decision:** RAM roles are attached to ECS instances via the `role_name` attribute on `alicloud_instance`, not via a separate `alicloud_ram_role_attachment` resource.

**Rationale:**
- Avoids circular dependency between identity and compute modules
- Simpler module composition
- Same end result

---

## Provider Configuration

```hcl
provider "alicloud" {
  # Region: var.alibaba_region (default: cn-hangzhou)
  # Credentials: ALICLOUD_ACCESS_KEY + ALICLOUD_SECRET_KEY env vars
  # NOTE: No credentials currently configured — plan-only mode
}
```

**Required Provider:** `aliyun/alicloud ~> 1.200`

---

## Known Limitations

1. **No Live Validation:** Without Alibaba Cloud credentials, `terraform plan` and `terraform apply` cannot be executed. All validation is static (`terraform validate`).

2. **Zone Selection:** Zone IDs are auto-selected from available zones. For production, explicitly specify zone IDs for deterministic placement.

3. **Image Availability:** The `alicloud_images` data source queries for Ubuntu 22.04 images. Image availability varies by region.

4. **NAS Mount Target:** The NAS mount target requires an explicit VSwitch ID. This is wired through the `nas_vswitch_id` variable.

5. **OSS Lifecycle Rules:** The `alicloud_oss_bucket_lifecycle` resource is not available in the current provider version. Lifecycle rules must be configured via the Alibaba Cloud Console or CLI.

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Agent 6 (Alibaba Engineer) | Initial Alibaba Cloud architecture |
