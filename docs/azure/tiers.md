# Azure Service Tiers

## Overview

This document describes how the provider-neutral service tiers (ECONOMY, STANDARD, ENTERPRISE) map to Azure-specific infrastructure. For the tier definitions themselves, see [Service Tier Architecture](../architecture/service-tiers.md).

**Key Principle:** Tiers are intent declarations. You say `service_tier = "standard"`, and the platform translates that into the appropriate Azure resources.

---

## Quick Reference

| | ECONOMY | STANDARD | ENTERPRISE |
|---|---------|----------|------------|
| **VMs** | 1 | 3 | 6 |
| **VM Size** | Standard_B2s | Standard_B2ms | Standard_D4s_v3 |
| **Availability Zones** | None | None | 3 |
| **Kubernetes** | K3s single-node | K3s multi-node | K3s multi-node (or AKS opt-in) |
| **Database** | Container (PostgreSQL) | Azure DB Flexible (Burstable) | Azure DB Flexible (HA) |
| **Load Balancer** | None | Standard LB | Standard LB (or App GW opt-in) |
| **Storage Account** | None | LRS | ZRS |
| **Key Vault** | No | No | Yes |
| **Managed Identity** | No | Yes | Yes |
| **Log Analytics** | No | Yes (30-day) | Yes (365-day) |
| **App Insights** | No | No | Yes |
| **Data Disks** | No | Yes (Premium_LRS) | Yes (Premium_ZRS) |
| **Estimated Cost** | ~$33/mo | ~$200/mo | ~$1000/mo |
| **Resources Created** | 10 | 48 | 81 |

---

## ECONOMY Tier

### Intent
Minimal viable PKI platform for development, testing, and small-scale use.

### Azure Resources

| Resource | Configuration | Notes |
|----------|---------------|-------|
| **Resource Group** | 1 | Contains all resources |
| **Virtual Network** | 10.0.0.0/16 | Single VNet |
| **Subnet** | 10.0.1.0/24 ("main") | Single subnet |
| **NSG** | Deny-all + SSH (optional) + NodePort | Minimal rules |
| **VM** | Standard_B2s, Ubuntu 22.04 | Burstable, 2 vCPU, 4GB RAM |
| **OS Disk** | StandardSSD_LRS, 30GB | Minimal storage |
| **Public IP** | Disabled by default | Cost and security |
| **Kubernetes** | K3s single-node | All components co-located |
| **Database** | PostgreSQL container | Local-path storage |
| **Secrets** | OpenBao standalone | Raft storage |

### What's NOT Created

- ❌ No AKS
- ❌ No Azure Database for PostgreSQL
- ❌ No Load Balancer
- ❌ No Application Gateway
- ❌ No NAT Gateway
- ❌ No Key Vault
- ❌ No Storage Account
- ❌ No Managed Identity
- ❌ No Log Analytics
- ❌ No Application Insights
- ❌ No Data Disks
- ❌ No Multi-Zone

### Cost Breakdown (Estimated)

| Resource | Monthly Cost |
|----------|-------------|
| Standard_B2s VM | ~$30.00 |
| StandardSSD_LRS 30GB | ~$2.40 |
| **Total** | **~$32.40** |

### Usage

```hcl
# terraform.tfvars
service_tier = "economy"
```

---

## STANDARD Tier

### Intent
Production-ready PKI platform with high availability for critical services.

### Azure Resources

| Resource | Configuration | Notes |
|----------|---------------|-------|
| **Resource Group** | 1 | Contains all resources |
| **Virtual Network** | 10.0.0.0/16 | Single VNet |
| **Subnet** | 10.0.1.0/24 ("main") | Single subnet |
| **NSG** | Deny-all + SSH + K3s HA + LB probes + HTTP/HTTPS | Multi-node rules |
| **VMs** | 3x Standard_B2ms, Ubuntu 22.04 | Burstable, 2 vCPU, 8GB RAM each |
| **OS Disks** | Premium_LRS, 50GB each | Better performance |
| **Data Disks** | Premium_LRS, 50GB each | For K3s data, Longhorn |
| **Public IPs** | Optional | Disabled by default |
| **Load Balancer** | Standard SKU | K3s API + HTTP/HTTPS |
| **Database** | Azure DB for PostgreSQL Flexible (B1ms) | Burstable, 32GB storage |
| **Storage Account** | LRS | Backups + registry containers |
| **Managed Identity** | User-assigned | For storage access |
| **Log Analytics** | 30-day retention | VM + NSG diagnostics |
| **Kubernetes** | K3s multi-node (1 server, 2 agents) | HA control plane |

### What's NOT Created

- ❌ No AKS (opt-in only)
- ❌ No Application Gateway (opt-in only)
- ❌ No NAT Gateway
- ❌ No Key Vault
- ❌ No Application Insights
- ❌ No Multi-Zone
- ❌ No Geo-Redundant Backups

### Cost Breakdown (Estimated)

| Resource | Monthly Cost |
|----------|-------------|
| 3x Standard_B2ms VMs | ~$180.00 |
| 3x Premium_LRS 50GB OS | ~$12.00 |
| 3x Premium_LRS 50GB Data | ~$15.00 |
| Standard LB | ~$18.00 |
| Azure DB Flexible B1ms | ~$12.00 |
| Storage Account LRS | ~$5.00 |
| Log Analytics | ~$10.00 |
| **Total** | **~$252.00** |

### Usage

```hcl
# terraform.tfvars
service_tier = "standard"
alert_email  = "admin@example.com"  # For monitoring alerts
```

---

## ENTERPRISE Tier

### Intent
Mission-critical PKI platform with maximum availability, compliance, and scale.

### Azure Resources

| Resource | Configuration | Notes |
|----------|---------------|-------|
| **Resource Group** | 1 | Contains all resources |
| **Virtual Network** | 10.0.0.0/16 | Single VNet |
| **Subnets** | "main" (10.0.1.0/24) + "private" (10.0.2.0/24) | Public + private |
| **NSG** | Deny-all + SSH + K3s HA + LB probes + HTTP/HTTPS | Full rules |
| **VMs** | 6x Standard_D4s_v3, Ubuntu 22.04, zones 1-3 | 4 vCPU, 16GB RAM each |
| **OS Disks** | Premium_ZRS, 100GB each | Zone-redundant |
| **Data Disks** | Premium_ZRS, 100GB each | Zone-redundant |
| **Public IPs** | Optional | Disabled by default |
| **Load Balancer** | Standard SKU, zone-redundant | K3s API + HTTP/HTTPS |
| **Database** | Azure DB for PostgreSQL Flexible (D2s_v3, HA) | Zone-redundant, 128GB |
| **Storage Account** | ZRS | Backups + registry + logs |
| **Key Vault** | Standard SKU, RBAC | CA keys, secrets |
| **Managed Identity** | User-assigned | For storage + Key Vault |
| **Log Analytics** | 365-day retention | Full diagnostics |
| **App Insights** | Enabled | Application monitoring |
| **Kubernetes** | K3s multi-node (3 servers, 3 agents) | HA control plane, multi-zone |

### Optional Add-Ons (Opt-In)

| Feature | Variable | Additional Cost |
|---------|----------|-----------------|
| **AKS** | `enable_aks = true` | ~$70+/mo |
| **App Gateway** | `enable_app_gateway = true` | ~$140+/mo |
| **Azure CSI** | `enable_azure_csi = true` | Minimal |
| **Azure CCM** | `enable_azure_ccm = true` | Minimal |

### Cost Breakdown (Estimated)

| Resource | Monthly Cost |
|----------|-------------|
| 6x Standard_D4s_v3 VMs | ~$840.00 |
| 6x Premium_ZRS 100GB OS | ~$48.00 |
| 6x Premium_ZRS 100GB Data | ~$60.00 |
| Standard LB (zone-redundant) | ~$18.00 |
| Azure DB Flexible D2s_v3 HA | ~$200.00 |
| Storage Account ZRS | ~$5.00 |
| Key Vault | ~$1.00 |
| Log Analytics (365-day) | ~$10.00 |
| App Insights | ~$10.00 |
| **Total** | **~$1,192.00** |

### Usage

```hcl
# terraform.tfvars
service_tier = "enterprise"
alert_email  = "sre@example.com"

# Optional: Enable Azure integrations
enable_azure_csi = true
enable_azure_ccm = true
```

---

## Tier Comparison: Azure-Specific Features

| Azure Feature | ECONOMY | STANDARD | ENTERPRISE |
|---------------|---------|----------|------------|
| **VM Series** | B (burstable) | B (burstable) | D (general purpose) |
| **Disk Type** | StandardSSD_LRS | Premium_LRS | Premium_ZRS |
| **Disk Size** | 30GB | 50GB | 100GB |
| **Availability Zones** | 0 | 0 | 3 |
| **Subnet Count** | 1 | 1 | 2 |
| **LB SKU** | N/A | Standard | Standard |
| **PostgreSQL SKU** | N/A | B_Standard_B1ms | GP_Standard_D2s_v3 |
| **PostgreSQL Storage** | N/A | 32GB | 128GB |
| **PostgreSQL HA** | N/A | No | Zone-Redundant |
| **PostgreSQL Backup** | N/A | 7-day | 35-day, geo-redundant |
| **Storage Replication** | N/A | LRS | ZRS |
| **Key Vault SKU** | N/A | N/A | Standard |
| **Log Retention** | N/A | 30 days | 365 days |
| **Private DNS** | N/A | N/A | Yes (PostgreSQL) |
| **Blob Versioning** | N/A | No | Yes |
| **Lifecycle Policy** | N/A | No | Yes (cool→archive→delete) |

---

## Tier Upgrade Path

```
ECONOMY ──► STANDARD ──► ENTERPRISE
   │            │            │
   │            │            │
   ▼            ▼            ▼
1 VM         3 VMs        6 VMs
No LB        Std LB       Std LB (zones)
Container DB Flexible DB  HA Flexible DB
No storage   LRS storage  ZRS storage
No identity  Managed ID   Managed ID + KV
No monitor   Log Analytics Log Analytics + App Insights
~$33/mo      ~$252/mo     ~$1,192/mo
```

### Upgrade Steps

**ECONOMY → STANDARD:**
1. Change `service_tier = "standard"` in terraform.tfvars
2. Run `terraform plan` — review the 38 new resources
3. Run `terraform apply`
4. K3s multi-node cluster is bootstrapped automatically
5. Argo CD syncs the same GitOps repository

**STANDARD → ENTERPRISE:**
1. Change `service_tier = "enterprise"` in terraform.tfvars
2. Run `terraform plan` — review the 33 new resources
3. Run `terraform apply`
4. VMs are distributed across availability zones
5. Key Vault is populated with CA keys
6. Monitoring is fully enabled

**No re-architecture required.** The same GitOps repository, the same manifests, the same application code. Only the infrastructure layer changes.

---

## Cost Guardrails

### Economy Tier Violations

The following will cause `terraform plan` to **fail** in economy tier:

```
ECONOMY TIER VIOLATION: The following resources are not allowed
in economy tier: aks_enabled, app_gateway, nat_gateway, ha_postgres,
multi_vm, key_vault, load_balancer, storage_account, log_analytics
```

### Cost Report

Every plan outputs a `cost_report` showing exactly what will be created:

```bash
terraform plan -var="service_tier=standard" | grep -A 20 cost_report
```

### Estimated Monthly Cost

Every plan outputs an `estimated_monthly_cost_usd`:

```bash
terraform plan -var="service_tier=standard" | grep estimated_monthly_cost
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Azure Tier Expansion Engineer | Initial Azure tiers document |
