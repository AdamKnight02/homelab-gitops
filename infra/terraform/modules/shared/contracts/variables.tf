# =============================================================================
# Contract Validation Variables
# =============================================================================
# These variables are used by the contract validation module to verify
# that a provider implementation conforms to the v1 contract.
# =============================================================================

variable "provider_name" {
  description = "Name of the cloud provider being validated (azure, aws, alibaba)."
  type        = string

  validation {
    condition     = contains(["azure", "aws", "alibaba"], var.provider_name)
    error_message = "Provider name must be one of: azure, aws, alibaba."
  }
}

variable "service_tier" {
  description = "Service tier being validated."
  type        = string

  validation {
    condition     = contains(["economy", "standard", "enterprise"], lower(var.service_tier))
    error_message = "Service tier must be one of: economy, standard, enterprise."
  }
}

variable "tags" {
  description = "Tags map to validate against required tags."
  type        = map(string)
  default     = {}
}

variable "outputs" {
  description = "Map of output names to their presence (true = exists)."
  type        = map(bool)
  default     = {}
}

variable "inputs" {
  description = "Map of input names to their presence (true = exists)."
  type        = map(bool)
  default     = {}
}

variable "resource_names" {
  description = "Map of resource types to their generated names for naming validation."
  type        = map(string)
  default     = {}
}

variable "instance_count" {
  description = "Number of instances/VMs being deployed."
  type        = number
  default     = 1
}

variable "features_enabled" {
  description = "Map of feature names to whether they are enabled."
  type        = map(bool)
  default     = {}
}
