# =============================================================================
# Azure Tier Config Module — Variables
# =============================================================================
# These variables are passed from the root module to resolve tier-driven
# configuration. This module has no resources — only locals and outputs.
# =============================================================================

variable "service_tier" {
  description = "Service tier: economy, standard, or enterprise"
  type        = string
  default     = "economy"
}

variable "azure_vm_size_override" {
  description = "Override the tier-driven VM size"
  type        = string
  default     = ""
}

variable "azure_public_ip_enabled" {
  description = "Whether public IPs are enabled"
  type        = bool
  default     = false
}

variable "network_cidr" {
  description = "CIDR block for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the primary subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "enable_aks" {
  description = "Enable AKS (enterprise tier only, opt-in)"
  type        = bool
  default     = false
}

variable "enable_app_gateway" {
  description = "Enable Application Gateway (enterprise tier only, opt-in)"
  type        = bool
  default     = false
}
