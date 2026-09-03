# Azure Terraform Module

## Overview

This module provisions a minimal Azure environment for running K3s and the Machine Identity Platform.

## Resources Created

| Resource | Type | Purpose |
|----------|------|---------|
| Resource Group | `azurerm_resource_group` | Container for all resources |
| Virtual Network | `azurerm_virtual_network` | Network isolation |
| Subnet | `azurerm_subnet` | VM subnet |
| NSG | `azurerm_network_security_group` | Firewall rules |
| Public IP | `azurerm_public_ip` | VM access |
| Network Interface | `azurerm_network_interface` | VM networking |
| Linux VM | `azurerm_linux_virtual_machine` | K3s host |

## Usage

```bash
cd infra/terraform/azure

# Initialize
terraform init

# Validate
terraform validate

# Plan (PLAN-ONLY)
terraform plan -out=azure.tfplan

# DO NOT APPLY - Azure is PLAN-ONLY for this lab
```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `azure_subscription_id` | Azure Subscription ID | (required) |
| `azure_region` | Azure region | `eastus` |
| `environment` | Environment name | `azure` |
| `vm_size` | VM size | `Standard_B1s` |
| `vm_admin_username` | Admin username | `ubuntu` |
| `ssh_public_key` | SSH public key | (required) |
| `vnet_cidr` | VNet CIDR | `10.0.0.0/16` |
| `subnet_cidr` | Subnet CIDR | `10.0.1.0/24` |
| `os_disk_size` | OS disk size (GB) | `30` |

## Outputs

| Output | Description |
|--------|-------------|
| `resource_group_name` | Resource group name |
| `vm_name` | VM name |
| `vm_public_ip` | Public IP address |
| `vm_private_ip` | Private IP address |
| `ssh_command` | SSH connection command |
| `k3s_kubeconfig` | Kubeconfig copy command |

## Cost

Estimated monthly cost if deployed: ~$18

No resources will be created (PLAN-ONLY).
