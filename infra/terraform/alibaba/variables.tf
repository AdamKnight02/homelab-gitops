# =============================================================================
# Alibaba Cloud Root Module — Variables
# =============================================================================
# Alibaba Cloud-specific variables. Common variables are inherited from the
# shared module or redefined here with Alibaba-specific defaults.
# =============================================================================

# ---------------------------------------------------------------------------
# Service Tier (tier-driven composition)
# ---------------------------------------------------------------------------
variable "service_tier" {
  description = "Service tier: economy, standard, or enterprise. Controls resource count, HA, and features."
  type        = string
  default     = "economy"

  validation {
    condition     = contains(["economy", "standard", "enterprise"], lower(var.service_tier))
    error_message = "Service tier must be one of: economy, standard, enterprise."
  }
}

variable "enable_ack" {
  description = "Enable ACK (Alibaba Container Service for Kubernetes) instead of K3s (enterprise tier only, opt-in)."
  type        = bool
  default     = false
}

variable "alibaba_instance_type_override" {
  description = "Override the tier-default ECS instance type. Empty string uses tier default."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Alibaba Cloud Account and Region
# ---------------------------------------------------------------------------
variable "alibaba_region" {
  description = "Alibaba Cloud region for resource deployment."
  type        = string
  default     = "cn-hangzhou"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+$", var.alibaba_region))
    error_message = "Alibaba Cloud region must be a valid region identifier (e.g., cn-hangzhou)."
  }
}

# ---------------------------------------------------------------------------
# Resource Naming
# ---------------------------------------------------------------------------
variable "name_prefix" {
  description = "Prefix for all Alibaba Cloud resource names."
  type        = string
  default     = "pki"
}

# ---------------------------------------------------------------------------
# Compute — ECS
# ---------------------------------------------------------------------------
variable "alibaba_admin_username" {
  description = "Admin username for ECS instances."
  type        = string
  default     = "root"
}

variable "alibaba_ssh_public_key" {
  description = "SSH public key for ECS access. If empty, a new key pair is generated."
  type        = string
  default     = ""
}

variable "alibaba_root_volume_size" {
  description = "Root disk size in GB. Tier defaults: economy=30, standard=50, enterprise=100."
  type        = number
  default     = 30

  validation {
    condition     = var.alibaba_root_volume_size >= 20 && var.alibaba_root_volume_size <= 500
    error_message = "Root volume must be between 20 and 500 GB."
  }
}

variable "alibaba_root_volume_category" {
  description = "Root disk category. cloud_efficiency is cheapest; cloud_essd is fastest."
  type        = string
  default     = "cloud_efficiency"

  validation {
    condition     = contains(["cloud_efficiency", "cloud_ssd", "cloud_essd"], var.alibaba_root_volume_category)
    error_message = "Disk category must be cloud_efficiency, cloud_ssd, or cloud_essd."
  }
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "alibaba_vpc_cidr" {
  description = "CIDR block for the Alibaba Cloud VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "alibaba_subnet_cidr" {
  description = "CIDR block for the Alibaba Cloud VSwitch (subnet)."
  type        = string
  default     = "10.0.1.0/24"
}

variable "alibaba_zone_id" {
  description = "Zone ID for the VSwitch. Auto-selected if empty."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Cost Control
# ---------------------------------------------------------------------------
variable "alibaba_associate_public_ip" {
  description = "Whether to associate a public IP (via bandwidth). Disable to avoid cost and exposure."
  type        = bool
  default     = false
}

variable "alibaba_internet_max_bandwidth_out" {
  description = "Maximum outbound bandwidth in Mbps (0 = no public IP)."
  type        = number
  default     = 0

  validation {
    condition     = var.alibaba_internet_max_bandwidth_out >= 0 && var.alibaba_internet_max_bandwidth_out <= 100
    error_message = "Bandwidth must be between 0 and 100 Mbps."
  }
}

# ---------------------------------------------------------------------------
# RAM (Identity)
# ---------------------------------------------------------------------------
variable "alibaba_create_ram_role" {
  description = "Whether to create a dedicated RAM role for ECS instances."
  type        = bool
  default     = true
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
  description = "CIDR blocks allowed to SSH to instances."
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
