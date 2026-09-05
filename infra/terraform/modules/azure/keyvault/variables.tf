variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "naming" {
  description = "Naming convention outputs from shared/naming module"
  type = object({
    keyvault_name = string
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "object_ids" {
  description = "Map of principal IDs to grant access policies"
  type        = map(string)
}

variable "config" {
  description = "Key Vault configuration object"
  type = object({
    sku_name                    = optional(string, "standard")
    enabled_for_disk_encryption = optional(bool, true)
    purge_protection_enabled    = optional(bool, true)
    soft_delete_retention_days  = optional(number, 90)
  })
}
