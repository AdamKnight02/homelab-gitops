# =============================================================================
# Azure Secrets Module — Variables
# =============================================================================

variable "name" {
  description = "Name prefix for secrets resources"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "enable_key_vault" {
  description = "Whether to create a Key Vault"
  type        = bool
  default     = false
}

variable "key_vault_name" {
  description = "Globally unique Key Vault name (3-24 chars, alphanumeric and dashes)"
  type        = string
  default     = ""

  validation {
    condition     = var.key_vault_name == "" || can(regex("^[a-zA-Z0-9-]{3,24}$", var.key_vault_name))
    error_message = "Key Vault name must be 3-24 alphanumeric characters and dashes."
  }
}

variable "sku_name" {
  description = "Key Vault SKU (standard or premium)"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "SKU must be standard or premium."
  }
}

variable "soft_delete_retention_days" {
  description = "Soft delete retention in days"
  type        = number
  default     = 90
}

variable "purge_protection_enabled" {
  description = "Enable purge protection (recommended for production)"
  type        = bool
  default     = true
}

variable "network_default_action" {
  description = "Default network ACL action (Allow or Deny)"
  type        = string
  default     = "Deny"
}

variable "allowed_subnet_ids" {
  description = "List of subnet IDs allowed to access Key Vault"
  type        = list(string)
  default     = []
}

variable "allowed_ip_ranges" {
  description = "List of IP ranges allowed to access Key Vault"
  type        = list(string)
  default     = []
}

variable "enable_ca_keys" {
  description = "Create CA signing keys in Key Vault"
  type        = bool
  default     = false
}

variable "enable_openbao_auto_unseal" {
  description = "Create placeholder for OpenBao auto-unseal key"
  type        = bool
  default     = false
}

variable "db_connection_string" {
  description = "Database connection string to store in Key Vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
