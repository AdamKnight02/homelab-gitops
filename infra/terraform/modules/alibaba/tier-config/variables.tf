# =============================================================================
# Alibaba Cloud Tier Configuration Module — Variables
# =============================================================================

variable "service_tier" {
  description = "Service tier: economy, standard, or enterprise. Controls resource count, HA, and features."
  type        = string
  default     = "economy"

  validation {
    condition     = contains(["economy", "standard", "enterprise"], lower(var.service_tier))
    error_message = "Service tier must be one of: economy, standard, enterprise."
  }
}

variable "alibaba_instance_type_override" {
  description = "Override the tier-default ECS instance type. Empty string uses tier default."
  type        = string
  default     = ""
}

variable "alibaba_associate_public_ip" {
  description = "Whether to associate public IPs with ECS instances."
  type        = bool
  default     = false
}

variable "enable_ack" {
  description = "Enable ACK (Alibaba Container Service for Kubernetes) instead of K3s (enterprise tier only, opt-in)."
  type        = bool
  default     = false
}
