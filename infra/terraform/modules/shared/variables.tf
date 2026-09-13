# =============================================================================
# Common Variables
# =============================================================================
# These variables are shared across Azure and AWS environments.
# Each root module can override defaults via terraform.tfvars or -var flags.
# =============================================================================

# ---------------------------------------------------------------------------
# Project Identity
# ---------------------------------------------------------------------------
variable "project_name" {
  description = "Name of the project. Used in resource naming and tagging."
  type        = string
  default     = "pki-cloudlab"
}

variable "environment" {
  description = "Environment identifier. Must be one of: lab, dev, staging, prod."
  type        = string
  default     = "lab"

  validation {
    condition     = contains(["lab", "dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: lab, dev, staging, prod."
  }
}

# ---------------------------------------------------------------------------
# Ownership and Governance
# ---------------------------------------------------------------------------
variable "owner" {
  description = "Email or identifier of the person/team responsible for this infrastructure."
  type        = string
  default     = "homelab-admin"
}

variable "managed_by" {
  description = "Tool or process managing this resource."
  type        = string
  default     = "terraform"
}

variable "ephemeral" {
  description = "Whether this infrastructure is temporary and should be destroyed after use."
  type        = bool
  default     = true
}

variable "cost_center" {
  description = "Cost center or budget code for chargeback."
  type        = string
  default     = "homelab"
}

# ---------------------------------------------------------------------------
# Compute Sizing
# ---------------------------------------------------------------------------
variable "vm_size" {
  description = "VM size / instance type. Defaults to smallest viable for K3s."
  type        = string
  default     = "small" # Interpreted by each cloud module
}

variable "vm_count" {
  description = "Number of VMs to create. Default 1 for single-node K3s."
  type        = number
  default     = 1

  validation {
    condition     = var.vm_count >= 1 && var.vm_count <= 3
    error_message = "VM count must be between 1 and 3 for lab environments."
  }
}

# ---------------------------------------------------------------------------
# Network Configuration
# ---------------------------------------------------------------------------
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
  description = "CIDR blocks allowed to SSH to VMs. Default denies all (use bastion/serial console)."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# K3s Bootstrap
# ---------------------------------------------------------------------------
variable "k3s_version" {
  description = "K3s release channel or version to install."
  type        = string
  default     = "v1.30"
}

variable "argocd_version" {
  description = "Argo CD version to install via Helm or manifest."
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
# PKI Platform Configuration
# ---------------------------------------------------------------------------
variable "trust_domain" {
  description = "SPIFFE trust domain for workload identity."
  type        = string
  default     = "cloudlab.local"
}

variable "pki_namespace" {
  description = "Kubernetes namespace for PKI workloads."
  type        = string
  default     = "pki"
}

# ---------------------------------------------------------------------------
# Feature Flags
# ---------------------------------------------------------------------------
variable "enable_monitoring" {
  description = "Enable Prometheus/Grafana monitoring stack."
  type        = bool
  default     = false # Disabled by default to reduce cost
}

variable "enable_spire" {
  description = "Enable SPIRE/SPIFFE workload identity."
  type        = bool
  default     = true
}

variable "enable_openbao" {
  description = "Enable OpenBao secrets management."
  type        = bool
  default     = true
}
