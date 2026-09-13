# =============================================================================
# Azure Root Module — Variables
# =============================================================================
# Azure-specific variables. Common variables are inherited from the shared
# module or redefined here with Azure-specific defaults.
#
# TIER SUPPORT: The service_tier variable drives all resource decisions.
# See infra/terraform/modules/azure/tier-config.tf for the mapping.
# =============================================================================

# ---------------------------------------------------------------------------
# Service Tier (PRIMARY DRIVER)
# ---------------------------------------------------------------------------
variable "service_tier" {
  description = "Service tier: economy, standard, or enterprise. Determines all infrastructure topology."
  type        = string
  default     = "economy"

  validation {
    condition     = contains(["economy", "standard", "enterprise"], lower(var.service_tier))
    error_message = "Service tier must be one of: economy, standard, enterprise."
  }
}

# ---------------------------------------------------------------------------
# Tier Override Variables (escape hatches — use with caution)
# ---------------------------------------------------------------------------
variable "azure_vm_size_override" {
  description = "Override the tier-driven VM size. Empty = use tier default."
  type        = string
  default     = ""
}

variable "enable_aks" {
  description = "Enable AKS instead of K3s (enterprise tier only, opt-in)."
  type        = bool
  default     = false
}

variable "enable_app_gateway" {
  description = "Enable Application Gateway instead of standard LB (enterprise tier only, opt-in)."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Azure Subscription and Region
# ---------------------------------------------------------------------------
variable "azure_subscription_id" {
  description = "Azure Subscription ID. If empty, uses current CLI context."
  type        = string
  default     = ""
  sensitive   = false
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID. If empty, uses current CLI context."
  type        = string
  default     = ""
  sensitive   = false
}

variable "azure_region" {
  description = "Azure region for resource deployment."
  type        = string
  default     = "eastus"

  validation {
    condition     = contains(["eastus", "westus2", "westeurope", "northeurope", "centralus", "southcentralus"], var.azure_region)
    error_message = "Region must be a common Azure region."
  }
}

# ---------------------------------------------------------------------------
# Resource Naming
# ---------------------------------------------------------------------------
variable "resource_group_name" {
  description = "Name of the Azure Resource Group. Auto-generated if empty."
  type        = string
  default     = ""
}

variable "name_prefix" {
  description = "Prefix for all Azure resource names."
  type        = string
  default     = "pki"
}

# ---------------------------------------------------------------------------
# Compute — Azure VM
# ---------------------------------------------------------------------------
variable "azure_vm_size" {
  description = "Azure VM size. Default is smallest viable for K3s (Standard_B2s)."
  type        = string
  default     = "Standard_B2s"

  validation {
    condition     = can(regex("^Standard_[BDF]", var.azure_vm_size))
    error_message = "VM size should be a Burstable or low-cost series for lab environments."
  }
}

variable "azure_vm_os" {
  description = "OS image for the Azure VM."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

variable "azure_admin_username" {
  description = "Admin username for the Azure VM. SSH key auth strongly preferred."
  type        = string
  default     = "labadmin"
}

variable "azure_ssh_public_key" {
  description = "SSH public key for VM access. If empty, a new key pair is generated."
  type        = string
  default     = ""
}

variable "azure_os_disk_size_gb" {
  description = "OS disk size in GB."
  type        = number
  default     = 30

  validation {
    condition     = var.azure_os_disk_size_gb >= 30 && var.azure_os_disk_size_gb <= 1024
    error_message = "OS disk must be between 30 and 1024 GB."
  }
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "azure_vnet_name" {
  description = "Name of the Azure Virtual Network. Auto-generated if empty."
  type        = string
  default     = ""
}

variable "azure_subnet_name" {
  description = "Name of the Azure Subnet. Auto-generated if empty."
  type        = string
  default     = ""
}

variable "azure_nsg_name" {
  description = "Name of the Network Security Group. Auto-generated if empty."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Cost Control
# ---------------------------------------------------------------------------
variable "azure_public_ip_enabled" {
  description = "Whether to allocate a public IP. Disable to avoid cost and exposure."
  type        = bool
  default     = false
}

variable "azure_accelerated_networking" {
  description = "Enable accelerated networking. Disabled for lab cost control."
  type        = bool
  default     = false
}



# =============================================================================
# Common Variables (duplicated from shared module for standalone validation)
# =============================================================================

variable "project_name" {
  description = "Name of the project. Used in resource naming and tagging."
  type        = string
  default     = "pki-cloudlab"
}

variable "environment" {
  description = "Environment identifier."
  type        = string
  default     = "lab"
}

variable "owner" {
  description = "Email or identifier of the person/team responsible."
  type        = string
  default     = "homelab-admin"
}

variable "managed_by" {
  description = "Tool or process managing this resource."
  type        = string
  default     = "terraform"
}

variable "ephemeral" {
  description = "Whether this infrastructure is temporary."
  type        = bool
  default     = true
}

variable "cost_center" {
  description = "Cost center or budget code."
  type        = string
  default     = "homelab"
}

variable "network_cidr" {
  description = "CIDR block for the virtual network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the primary subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "allow_ssh_cidr" {
  description = "CIDR blocks allowed to SSH to VMs."
  type        = list(string)
  default     = []
}

variable "k3s_version" {
  description = "K3s release channel or version to install."
  type        = string
  default     = "v1.30"
}

variable "argocd_version" {
  description = "Argo CD version to install."
  type        = string
  default     = "v2.12"
}

variable "git_repo_url" {
  description = "Git repository URL for Argo CD to sync."
  type        = string
  default     = "https://github.com/AdamKnight02/homelab-gitops.git"
}

variable "git_target_revision" {
  description = "Git branch or tag for Argo CD to track."
  type        = string
  default     = "main"
}

# ---------------------------------------------------------------------------
# Tier-Specific Variables (used by standard/enterprise tiers)
# ---------------------------------------------------------------------------
variable "alert_email" {
  description = "Email address for Azure Monitor alert notifications."
  type        = string
  default     = ""
}

variable "k3s_token" {
  description = "K3s cluster token for multi-node join. Auto-generated if empty."
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_azure_csi" {
  description = "Install Azure Disk/File CSI drivers on K3s."
  type        = bool
  default     = false
}

variable "enable_azure_ccm" {
  description = "Install Azure Cloud Controller Manager on K3s."
  type        = bool
  default     = false
}
