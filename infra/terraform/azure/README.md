# Azure PKI Platform — Terraform Root Module

## Status: Tier-Driven, Plan-Validated

This module deploys the Machine Identity Platform to Azure with three service tiers: **ECONOMY**, **STANDARD**, and **ENTERPRISE**.

## Quick Start

```bash
cd infra/terraform/azure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set service_tier
terraform init
terraform plan
terraform apply
```

## Service Tiers

| Tier | VMs | Database | LB | Storage | Key Vault | Monitoring | Cost/mo |
|------|-----|----------|----|---------|-----------|------------|---------|
| **ECONOMY** | 1 | Container | None | None | No | No | ~$33 |
| **STANDARD** | 3 | Azure DB Flexible | Standard LB | LRS | No | Log Analytics | ~$252 |
| **ENTERPRISE** | 6 | Azure DB Flexible HA | Standard LB | ZRS | Yes | Full | ~$1,192 |

See [docs/azure/tiers.md](../../../docs/azure/tiers.md) for detailed tier specifications.

## Architecture

```
ECONOMY:                          STANDARD/ENTERPRISE:
                                  
Resource Group                    Resource Group
    │                                 │
    ├── VNet                          ├── VNet
    │   └── Subnet                    │   ├── Subnet "main"
    │       └── NSG                   │   └── Subnet "private" (ent)
    │                                 │       └── NSG (tier-aware)
    ├── Public IP (opt)               │
    ├── NIC                           ├── Managed Identity (std+)
    └── VM (B2s)                      ├── Load Balancer (std+)
        └── K3s + Argo CD             ├── Azure Database (std+)
                                      ├── Storage Account (std+)
                                      ├── Key Vault (ent)
                                      ├── Log Analytics (std+)
                                      ├── App Insights (ent)
                                      └── 3-6 VMs (B2ms/D4s_v3)
                                          └── K3s HA + Argo CD
```

## Module Structure

The root module composes shared modules from `infra/terraform/modules/azure/`:

| Module | Purpose | Tiers |
|--------|---------|-------|
| `tier-config` | Central tier-to-resource mapping | All |
| `network` | VNet, subnets, NAT gateway | All |
| `security` | NSG with tier-aware rules | All |
| `identity` | Managed Identity + role assignments | Standard+ |
| `compute` | VMs, NICs, disks, public IPs | Standard+ |
| `storage` | Storage Account, containers, lifecycle | Standard+ |
| `database` | Azure Database for PostgreSQL Flexible | Standard+ |
| `secrets` | Key Vault, keys, secrets | Enterprise |
| `load-balancer` | Azure LB, App Gateway | Standard+ |
| `kubernetes-bootstrap` | K3s cloud-init generation | Standard+ |
| `monitoring-bootstrap` | Log Analytics, App Insights, alerts | Standard+ |

## Cost Guardrails

- **Economy guardrail:** Plan fails if AKS, App Gateway, NAT Gateway, HA PostgreSQL, or multi-VM is enabled in economy tier
- **Cost report:** Every plan outputs resource counts and estimated monthly cost
- **No silent surprises:** All expensive resources are opt-in or tier-gated

## Validation

```bash
# Validate all tiers
terraform validate

# Plan each tier
terraform plan -var="service_tier=economy"     # 10 resources
terraform plan -var="service_tier=standard"    # 48 resources
terraform plan -var="service_tier=enterprise"  # 81 resources
```

## Documentation

- [Azure Architecture](../../../docs/azure/architecture.md) — Module structure, resource topology, design decisions
- [Azure Tiers](../../../docs/azure/tiers.md) — Detailed tier specifications and cost breakdowns
- [Azure Deployment Guide](../../../docs/azure/deployment.md) — Step-by-step deployment instructions

## Security Notes

- No public IP by default
- NSG denies all inbound traffic
- SSH key auto-generated (ED25519)
- All resources in single resource group for easy cleanup
- Managed Identity for service-to-service auth (Standard+)
- Key Vault for secrets management (Enterprise)
