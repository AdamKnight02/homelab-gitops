# Alibaba Cloud PKI Platform — Terraform Root Module

## Status: STATIC VALIDATION ONLY

**NO ALIBABA CLOUD RESOURCES WILL BE CREATED.**

This module is for design, validation, and documentation only. The Alibaba Cloud CLI is not installed and no credentials are configured in this environment.

## Architecture

```
Alibaba Cloud Account
    |
    v
VPC (10.0.0.0/16)
    |
    v
VSwitch (10.0.1.0/24)
    |
    v
Security Group (deny-all inbound)
    |
    v
ECS Instance(s) (tier-dependent)
    |
    v
K3s (via cloud-init)
    |
    v
Argo CD (via cloud-init)
    |
    v
GitOps PKI Platform
```

## Service Tiers

This module implements the tier-driven architecture defined in `docs/architecture/service-tiers.md`:

| Tier | ECS Instances | RDS | SLB | OSS | KMS | Use Case |
|------|---------------|-----|-----|-----|-----|----------|
| **ECONOMY** | 1 (t6-c1m2.large) | No | No | No | No | Dev/test, PoC |
| **STANDARD** | 3 (g7.large) | Yes (basic) | Yes (SLB) | Yes | No | Production, SME |
| **ENTERPRISE** | 6+ (g7.xlarge) | Yes (HA) | Yes (NLB) | Yes (versioned) | Yes | Enterprise, regulated |

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Compute | ECS (not ACK) | Cost, portability, similarity to homelab |
| Kubernetes | K3s (not ACK) | Cost, simplicity, GitOps-friendly |
| Public IP | Disabled by default | Cost (~$3/mo) and security |
| SSH Access | Key-only, no inbound by default | Use Alibaba Cloud Workbench or Session Manager |
| OS Disk | cloud_efficiency 30GB (ECONOMY) | Minimum viable; ~$2/mo |
| Network | Single VPC + VSwitch | Simplicity for lab |

## Cost Traps Avoided

- ❌ ACK (managed Kubernetes) — ~$60/month minimum
- ❌ ApsaraDB RDS PostgreSQL — ~$80-160/month (ECONOMY tier)
- ❌ SLB/NLB — ~$15-25/month (ECONOMY tier)
- ❌ NAT Gateway — ~$30/month + data transfer
- ❌ EIP — ~$3/month (disabled by default)
- ❌ KMS — ~$1-10/month (ECONOMY tier)
- ❌ CloudMonitor — ~$5-20/month (ECONOMY tier)

## Cost Guardrails

This module implements cost guardrails that report resource counts before apply:

```bash
terraform plan
# Review the COST GUARDRAILS REPORT in the plan output
```

**Guardrail Checks:**
- ECS instance count (max 10)
- Disk size (max 500GB)
- Unexpected RDS in ECONOMY tier
- Unexpected SLB in ECONOMY tier
- Unexpected NAT Gateway in ECONOMY tier
- Unexpected KMS in ECONOMY tier

## Validation Commands

```bash
cd infra/terraform/alibaba
terraform init
terraform validate
terraform plan
```

## Outputs

| Output | Description |
|--------|-------------|
| `vpc_id` | VPC ID |
| `instance_ids` | ECS instance IDs |
| `instance_private_ips` | Private IPs for internal access |
| `estimated_monthly_cost_usd` | ~$25-500/month depending on tier |
| `cost_warnings` | Cost guardrail warnings |
| `resource_report` | Resource count summary |

## Security Notes

- No public IP by default
- Security group denies all inbound traffic
- SSH key auto-generated (ED25519)
- All resources tagged for easy cleanup
- Terraform state contains sensitive data — never commit it
- Cloud-init contains no secrets

## Module Structure

```
alibaba/
├── versions.tf              # Provider version constraints
├── variables.tf             # Input variables (tier-driven)
├── locals.tf                # Local values (tier definitions)
├── main.tf                  # Resource composition
├── outputs.tf               # Outputs
├── terraform.tfvars.example # Example variables
└── README.md                # This file

modules/alibaba/
├── network/                 # VPC, VSwitch, NAT Gateway
├── security/                # Security Group rules
├── identity/                # RAM Role, Instance Profile
├── compute/                 # ECS instances
├── storage/                 # OSS, Cloud Disk
├── database/                # ApsaraDB RDS PostgreSQL
├── secrets/                 # KMS, Secrets Manager
├── load-balancer/           # SLB/NLB
├── kubernetes-bootstrap/    # K3s bootstrap via cloud-init
└── monitoring-bootstrap/    # CloudMonitor integration
```

## References

- [Service Tier Architecture](../../docs/architecture/service-tiers.md)
- [Containerization Model](../../docs/architecture/containerization-model.md)
- [Terraform Provider Contracts](../../docs/architecture/terraform-provider-contracts.md)
- [Provider Capability Matrix](../../docs/architecture/provider-capability-matrix.md)
