# Azure Deployment Guide

## Overview

This guide covers deploying the Machine Identity Platform to Azure using the tier-driven Terraform module. It assumes you have Azure CLI authenticated and Terraform installed.

---

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| **Terraform** | >= 1.10.0 | `terraform --version` |
| **Azure CLI** | >= 2.50 | `az --version` |
| **Azure Subscription** | Active | Pay-as-you-go or CSP |
| **RBAC** | Contributor | On the subscription or resource group |

### Verify Azure CLI Authentication

```bash
az account show
# Should show your subscription ID and tenant ID
```

### Verify Terraform

```bash
terraform --version
# Should show >= 1.10.0
```

---

## Quick Start

### 1. Choose Your Tier

| Tier | Use Case | Monthly Cost |
|------|----------|-------------|
| **economy** | Dev/test, POC, homelab | ~$33 |
| **standard** | Production, small team | ~$252 |
| **enterprise** | Mission-critical, regulated | ~$1,192 |

### 2. Configure Variables

```bash
cd infra/terraform/azure
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
# Minimal configuration for economy tier
service_tier = "economy"
azure_region = "eastus"
name_prefix  = "pki"
```

### 3. Initialize and Plan

```bash
terraform init
terraform plan
```

### 4. Review the Plan

Check the outputs:

```
service_tier               = "economy"
estimated_monthly_cost_usd = 32.4
cost_report                = {
  vm_count      = 1
  vm_size       = "Standard_B2s"
  ...
}
```

### 5. Apply

```bash
terraform apply
```

---

## Deployment by Tier

### ECONOMY Deployment

**What gets created:** 10 resources, single VM, K3s single-node.

```hcl
# terraform.tfvars
service_tier = "economy"
azure_region = "eastus"
name_prefix  = "pki"

# Optional: Enable public IP for direct access
# azure_public_ip_enabled = true

# Optional: Allow SSH from your IP
# allow_ssh_cidr = ["203.0.113.0/24"]
```

```bash
terraform init
terraform plan
terraform apply
```

**Post-deployment:**

```bash
# Get the VM's private IP
terraform output vm_private_ip

# Get the SSH private key
terraform output -raw ssh_private_key > ~/.ssh/pki-azure-key
chmod 600 ~/.ssh/pki-azure-key

# SSH to the VM (if public IP enabled)
ssh -i ~/.ssh/pki-azure-key labadmin@<public-ip>

# Or use Azure Serial Console
az serial-console connect -g <resource-group> -n <vm-name>
```

**Access K3s:**

```bash
# On the VM
sudo cat /etc/rancher/k3s/k3s.yaml

# Access Argo CD
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Initial password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

---

### STANDARD Deployment

**What gets created:** 48 resources, 3 VMs, K3s multi-node, Azure Database, Load Balancer, Storage Account, Log Analytics.

```hcl
# terraform.tfvars
service_tier = "standard"
azure_region = "eastus"
name_prefix  = "pki"
alert_email  = "admin@example.com"

# Optional: Allow SSH from your IP
# allow_ssh_cidr = ["203.0.113.0/24"]
```

```bash
terraform init
terraform plan
terraform apply
```

**Post-deployment:**

```bash
# Get all VM private IPs
terraform output vm_private_ips

# Get the load balancer public IP
terraform output lb_public_ip

# Get the database FQDN
terraform output database_fqdn

# Get the K3s token (for manual node join if needed)
terraform output -raw k3s_token
```

**Verify K3s cluster:**

```bash
# SSH to the first node (server)
ssh -i ~/.ssh/pki-azure-key labadmin@<first-vm-ip>

# Check cluster
sudo kubectl get nodes
# Should show 3 nodes: 1 server, 2 agents
```

---

### ENTERPRISE Deployment

**What gets created:** 81 resources, 6 VMs across 3 zones, K3s HA, HA Database, Key Vault, Full Monitoring.

```hcl
# terraform.tfvars
service_tier = "enterprise"
azure_region = "eastus"
name_prefix  = "pki"
alert_email  = "sre@example.com"

# Optional: Enable Azure integrations
enable_azure_csi = true
enable_azure_ccm = true

# Optional: Use AKS instead of K3s (adds ~$70/mo)
# enable_aks = true

# Optional: Use App Gateway instead of LB (adds ~$140/mo)
# enable_app_gateway = true
```

```bash
terraform init
terraform plan
terraform apply
```

**Post-deployment:**

```bash
# Get all VM private IPs (across zones)
terraform output vm_private_ips

# Get the Key Vault URI
terraform output key_vault_uri

# Get the database FQDN (HA)
terraform output database_fqdn

# Get the managed identity client ID
terraform output managed_identity_client_id
```

**Verify multi-zone deployment:**

```bash
# Check VM zones
az vm list -g <resource-group> --query "[].{Name:name, Zone:zones}" -o table

# Check K3s cluster
ssh -i ~/.ssh/pki-azure-key labadmin@<first-vm-ip>
sudo kubectl get nodes -o wide
```

---

## Configuration Reference

### Required Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `service_tier` | Service tier (economy/standard/enterprise) | `"economy"` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `azure_region` | Azure region | `"eastus"` |
| `name_prefix` | Resource name prefix | `"pki"` |
| `azure_public_ip_enabled` | Allocate public IPs | `false` |
| `allow_ssh_cidr` | SSH allowed CIDRs | `[]` |
| `azure_vm_size_override` | Override tier VM size | `""` |
| `k3s_version` | K3s release channel | `"v1.30"` |
| `argocd_version` | Argo CD version | `"v2.12"` |
| `git_repo_url` | GitOps repository URL | `"https://github.com/AdamKnight02/homelab-gitops.git"` |
| `git_target_revision` | Git branch/tag | `"main"` |
| `alert_email` | Alert notification email | `""` |
| `enable_aks` | Use AKS (enterprise only) | `false` |
| `enable_app_gateway` | Use App Gateway (enterprise only) | `false` |
| `enable_azure_csi` | Install Azure CSI drivers | `false` |
| `enable_azure_ccm` | Install Azure CCM | `false` |
| `k3s_token` | K3s cluster token | `""` (auto-generated) |

---

## Cost Management

### Pre-Apply Cost Check

Always review the cost report before applying:

```bash
terraform plan | grep -A 25 cost_report
```

### Economy Guardrail

The economy tier has a built-in guardrail that prevents accidental creation of expensive resources:

```bash
# This will FAIL:
terraform plan -var="service_tier=economy" -var="enable_aks=true"
# Error: ECONOMY TIER VIOLATION: ...
```

### Estimated Costs by Tier

| Tier | VMs | Disks | LB | DB | Storage | KV | Monitor | Total |
|------|-----|-------|----|----|---------|----|---------|-------|
| Economy | $30 | $2.40 | $0 | $0 | $0 | $0 | $0 | **~$33** |
| Standard | $180 | $27 | $18 | $12 | $5 | $0 | $10 | **~$252** |
| Enterprise | $840 | $108 | $18 | $200 | $5 | $1 | $20 | **~$1,192** |

### Cost Optimization Tips

1. **Use economy for dev/test** — it's designed to be minimal
2. **Disable public IPs** — saves $3.60/VM/month
3. **Use Azure Reservations** — up to 40% savings on VMs
4. **Enable auto-shutdown** — for dev/test VMs
5. **Use spot instances** — for non-critical worker nodes (not implemented yet)

---

## Cleanup

### Destroy All Resources

```bash
terraform destroy
```

This deletes the entire resource group and all resources within it.

### Partial Cleanup (Keep Resource Group)

```bash
# Remove specific modules
terraform destroy -target=module.compute
terraform destroy -target=module.database
```

---

## Troubleshooting

### Common Issues

**Issue:** `terraform plan` fails with "ECONOMY TIER VIOLATION"
**Solution:** Remove the forbidden variable or change to a higher tier.

**Issue:** `terraform plan` fails with "creation of new Basic SKU public IP addresses is no longer permitted"
**Solution:** This was fixed in the module. Update to the latest version.

**Issue:** K3s nodes can't join the cluster
**Solution:** Verify the NSG rules allow K3s traffic (ports 6443, 2379-2380, 8472, 10250) between VMs.

**Issue:** Azure Database connection fails
**Solution:** Check the firewall rules. Standard tier allows Azure services; Enterprise uses private endpoint.

**Issue:** Key Vault access denied
**Solution:** Verify the managed identity has the "Key Vault Secrets User" role assigned.

### Useful Commands

```bash
# Validate configuration
terraform validate

# Format configuration
terraform fmt -recursive

# Show current state
terraform show

# List all resources
terraform state list

# Get specific output
terraform output vm_private_ip
terraform output -raw ssh_private_key
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Azure Terraform Plan
on:
  pull_request:
    paths:
      - 'infra/terraform/azure/**'

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.10.0
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Terraform Init
        run: terraform init
        working-directory: infra/terraform/azure
      
      - name: Terraform Validate
        run: terraform validate
        working-directory: infra/terraform/azure
      
      - name: Terraform Plan (Economy)
        run: terraform plan -var="service_tier=economy" -input=false
        working-directory: infra/terraform/azure
      
      - name: Terraform Plan (Standard)
        run: terraform plan -var="service_tier=standard" -input=false
        working-directory: infra/terraform/azure
      
      - name: Terraform Plan (Enterprise)
        run: terraform plan -var="service_tier=enterprise" -input=false
        working-directory: infra/terraform/azure
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Azure Tier Expansion Engineer | Initial Azure deployment guide |
