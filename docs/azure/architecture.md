# Azure Architecture

## Overview

This document describes the Azure-specific architecture for the Machine Identity Platform. It covers the Terraform module structure, resource topology, and design decisions for deploying the PKI platform on Azure.

**Core Principle:** Tier-driven composition. The `service_tier` variable is the single input that determines all infrastructure topology. The existing Azure root module is preserved and extended, not rewritten.

---

## Module Structure

```
infra/terraform/
├── azure/                              # Root module (tier-aware)
│   ├── main.tf                         # Resource group, VNet, NSG, VMs, module calls
│   ├── locals.tf                       # Naming, tagging, tier-config import
│   ├── variables.tf                    # All variables including service_tier
│   ├── outputs.tf                      # Tier-aware outputs
│   ├── versions.tf                     # Provider constraints
│   ├── terraform.tfvars.example        # Example configuration
│   └── templates/
│       └── cloud-init.yaml.tpl         # Economy tier cloud-init (single node)
│
└── modules/azure/                      # Shared Azure modules
    ├── tier-config.tf                  # Central tier-to-resource mapping
    ├── variables.tf                    # Tier-config module variables
    ├── outputs.tf                      # Tier-config module outputs
    ├── network.tf                      # (legacy placeholder)
    │
    ├── network/                        # VNet, subnets, NAT gateway
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── versions.tf
    │
    ├── security/                       # NSG with tier-aware rules
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── versions.tf
    │
    ├── identity/                       # Managed Identity + role assignments
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── versions.tf
    │
    ├── compute/                        # VMs, NICs, disks, public IPs
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── versions.tf
    │
    ├── storage/                        # Storage Account, containers, lifecycle
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── versions.tf
    │
    ├── database/                       # Azure Database for PostgreSQL Flexible
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── versions.tf
    │
    ├── secrets/                        # Key Vault, keys, secrets
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── versions.tf
    │
    ├── load-balancer/                  # Azure LB, App Gateway
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── versions.tf
    │
    ├── kubernetes-bootstrap/           # K3s cloud-init generation
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── versions.tf
    │   └── templates/
    │       └── cloud-init.yaml.tpl     # Multi-node K3s cloud-init
    │
    └── monitoring-bootstrap/           # Log Analytics, App Insights, alerts
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── versions.tf
```

---

## Resource Topology by Tier

### ECONOMY (10 resources)

```
Azure Subscription
    │
    ▼
Resource Group
    │
    ├── Virtual Network (10.0.0.0/16)
    │   └── Subnet "main" (10.0.1.0/24)
    │       └── NSG (deny-all inbound, SSH optional, NodePort)
    │
    ├── Public IP (optional, disabled by default)
    │
    ├── Network Interface
    │
    └── Linux VM (Standard_B2s, Ubuntu 22.04)
        ├── OS Disk (StandardSSD_LRS, 30GB)
        └── cloud-init → K3s single-node + Argo CD
```

**Resources:** RG, VNet, Subnet, NSG, NSG association, NIC, VM, random suffix, TLS key, random K3s token = **10 resources**

**Monthly Cost:** ~$32-36

---

### STANDARD (48 resources)

```
Azure Subscription
    │
    ▼
Resource Group
    │
    ├── Virtual Network (10.0.0.0/16)
    │   └── Subnet "main" (10.0.1.0/24)
    │       └── NSG (deny-all, SSH, K3s HA rules, LB probes, HTTP/HTTPS)
    │
    ├── Managed Identity
    │   └── Role: Storage Blob Data Contributor
    │
    ├── Load Balancer (Standard SKU)
    │   ├── Public IP (Standard)
    │   ├── Backend Pool (3 NICs)
    │   ├── Health Probes (K3s API, HTTP)
    │   └── LB Rules (6443, 80, 443)
    │
    ├── Azure Database for PostgreSQL Flexible (Burstable B1ms)
    │   └── Database: cadb
    │
    ├── Storage Account (LRS)
    │   ├── Container: backups
    │   └── Container: registry
    │
    ├── Log Analytics Workspace (30-day retention)
    │   ├── VM Diagnostic Settings
    │   ├── NSG Diagnostic Settings
    │   ├── Action Group (email alerts)
    │   └── CPU Metric Alerts
    │
    └── 3x Linux VMs (Standard_B2ms, Ubuntu 22.04)
        ├── OS Disk (Premium_LRS, 50GB)
        ├── Data Disk (Premium_LRS, 50GB)
        ├── Managed Identity attached
        └── cloud-init → K3s server/agent + Argo CD
```

**Resources:** RG, VNet, Subnet, NSG, NSG assoc, 3x PIP, 3x NIC, 3x VM, 3x OS disk, 3x data disk, 3x disk attach, LB PIP, LB, backend pool, 2 probes, 3 rules, 3 backend assoc, PostgreSQL, database, firewall rule, storage account, 2 containers, identity, 2 role assignments, Log Analytics, 3 VM diag, NSG diag, action group, 3 CPU alerts, random suffix, TLS key, K3s token, random PG password = **48 resources**

**Monthly Cost:** ~$200

---

### ENTERPRISE (81 resources)

```
Azure Subscription
    │
    ▼
Resource Group
    │
    ├── Virtual Network (10.0.0.0/16)
    │   ├── Subnet "main" (10.0.1.0/24)
    │   └── Subnet "private" (10.0.2.0/24)
    │       └── NSG (deny-all, SSH, K3s HA, LB probes, HTTP/HTTPS)
    │
    ├── Managed Identity
    │   ├── Role: Key Vault Secrets User
    │   └── Role: Storage Blob Data Contributor
    │
    ├── Load Balancer (Standard SKU, zone-redundant)
    │   ├── Public IP (Standard, zones 1-3)
    │   ├── Backend Pool (6 NICs)
    │   ├── Health Probes (K3s API, HTTP)
    │   └── LB Rules (6443, 80, 443)
    │
    ├── Azure Database for PostgreSQL Flexible (GP D2s_v3, HA)
    │   ├── Zone-redundant HA
    │   ├── Geo-redundant backups
    │   ├── Private DNS Zone
    │   └── Database: cadb
    │
    ├── Storage Account (ZRS)
    │   ├── Container: backups (lifecycle: cool→archive→delete)
    │   ├── Container: registry
    │   ├── Container: logs
    │   └── Blob versioning enabled
    │
    ├── Key Vault (Standard SKU, RBAC)
    │   ├── CA Signing Key (RSA 4096, auto-rotation)
    │   ├── OCSP Signing Key (RSA 2048)
    │   ├── Secret: DB connection string
    │   └── Secret: OpenBao auto-unseal placeholder
    │
    ├── Log Analytics Workspace (365-day retention)
    │   ├── VM Diagnostic Settings (6 VMs)
    │   ├── NSG Diagnostic Settings
    │   ├── Action Group (email alerts)
    │   └── CPU Metric Alerts (6 VMs)
    │
    ├── Application Insights
    │
    └── 6x Linux VMs (Standard_D4s_v3, Ubuntu 22.04, zones 1-3)
        ├── OS Disk (Premium_ZRS, 100GB)
        ├── Data Disk (Premium_ZRS, 100GB)
        ├── Managed Identity attached
        └── cloud-init → K3s server/agent + Argo CD + Azure CSI/CCM
```

**Resources:** 81 total (all standard resources + enterprise additions)

**Monthly Cost:** ~$1000

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Tier driver** | `service_tier` variable | Single input controls all topology |
| **Economy preservation** | Inline resources in root module | Backward compatible with existing code |
| **Standard/Enterprise** | Module composition | Reusable, testable, follows contracts |
| **Kubernetes** | K3s (all tiers) | Cost, portability, homelab similarity |
| **AKS** | Opt-in only (enterprise) | Expensive ($70+/mo), not default |
| **Database** | Container → Flexible → Flexible HA | Progressive capability by tier |
| **Load Balancer** | None → Standard → Standard/AppGW | Basic LB deprecated March 2025 |
| **Storage** | None → LRS → ZRS | Progressive durability |
| **Key Vault** | Enterprise only | Cost control; OpenBao suffices for standard |
| **Managed Identity** | Standard+ | Secure service-to-service auth |
| **Monitoring** | None → Log Analytics → +App Insights | Progressive observability |
| **Static IPs** | Standard+ (predictable .4, .5, .6...) | K3s server URL needs known IP |
| **NAT Gateway** | Never default | Expensive ($32+/mo), opt-in only |

---

## Cost Guardrails

### Pre-Apply Validation

The root module includes a `terraform_data` resource with a `precondition` that fails the plan if economy tier has forbidden resources:

```hcl
resource "terraform_data" "economy_guardrail" {
  lifecycle {
    precondition {
      condition     = length(local.economy_violations) == 0
      error_message = "ECONOMY TIER VIOLATION: ..."
    }
  }
}
```

### Forbidden in Economy

The following resources trigger a plan failure in economy tier:

| Resource | Why Forbidden |
|----------|---------------|
| AKS | $70+/month minimum |
| Application Gateway | $140+/month |
| NAT Gateway | $32+/month |
| HA PostgreSQL | $200+/month |
| Multiple VMs | Economy is single-node |
| Key Vault | Unnecessary for dev/test |
| Load Balancer | $18+/month |
| Storage Account | $5+/month |
| Log Analytics | $10+/month |

### Cost Report

Every plan outputs a `cost_report` object with resource counts:

```json
{
  "vm_count": 1,
  "vm_size": "Standard_B2s",
  "managed_disks": 1,
  "managed_disk_total_gb": 30,
  "data_disks": 0,
  "nat_gateways": 0,
  "public_ips": 0,
  "postgres_servers": 0,
  "postgres_ha": false,
  "aks_clusters": 0,
  "load_balancers": 0,
  "app_gateways": 0,
  "storage_accounts": 0,
  "key_vaults": 0,
  "managed_identities": 0,
  "log_analytics": 0,
  "app_insights": 0
}
```

---

## Security Model

### Network Security

| Layer | Economy | Standard | Enterprise |
|-------|---------|----------|------------|
| **NSG Default** | Deny all inbound | Deny all inbound | Deny all inbound |
| **SSH** | Optional CIDR | Optional CIDR | Optional CIDR |
| **K3s API** | N/A (single node) | VirtualNetwork only | VirtualNetwork only |
| **K3s etcd** | N/A | VirtualNetwork only | VirtualNetwork only |
| **Flannel** | N/A | VirtualNetwork only | VirtualNetwork only |
| **Kubelet** | N/A | VirtualNetwork only | VirtualNetwork only |
| **LB Probes** | N/A | AzureLoadBalancer | AzureLoadBalancer |
| **HTTP/HTTPS** | N/A | Any (via LB) | Any (via LB) |
| **NodePort** | Any (economy) | N/A (LB instead) | N/A (LB instead) |

### Identity and Access

| Control | Economy | Standard | Enterprise |
|---------|---------|----------|------------|
| **VM Auth** | SSH key only | SSH key + Managed Identity | SSH key + Managed Identity |
| **Service Auth** | None | Managed Identity → Storage | Managed Identity → Storage + Key Vault |
| **Key Vault RBAC** | N/A | N/A | Enabled |
| **Secrets** | OpenBao (container) | OpenBao (container) | Key Vault + OpenBao |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Azure Tier Expansion Engineer | Initial Azure architecture document |
