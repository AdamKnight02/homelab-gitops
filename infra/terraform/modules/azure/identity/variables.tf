# =============================================================================
# Azure Identity Module — Variables
# =============================================================================

variable "name" {
  description = "Name prefix for identity resources"
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

variable "enable_managed_identity" {
  description = "Whether to create a user-assigned managed identity"
  type        = bool
  default     = false
}

variable "key_vault_id" {
  description = "ID of the Key Vault for role assignment (empty to skip)"
  type        = string
  default     = ""
}

variable "enable_key_vault_role" {
  description = "Enable Key Vault role assignment"
  type        = bool
  default     = false
}

variable "storage_account_id" {
  description = "ID of the Storage Account for role assignment (empty to skip)"
  type        = string
  default     = ""
}

variable "enable_storage_role" {
  description = "Enable Storage role assignment"
  type        = bool
  default     = false
}

variable "acr_id" {
  description = "ID of the Container Registry for role assignment (empty to skip)"
  type        = string
  default     = ""
}

variable "enable_acr_role" {
  description = "Enable ACR role assignment"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
