# =============================================================================
# Azure Storage Module — Variables
# =============================================================================

variable "name" {
  description = "Name prefix for storage resources"
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

variable "enable_storage_account" {
  description = "Whether to create a storage account"
  type        = bool
  default     = false
}

variable "storage_account_name" {
  description = "Globally unique storage account name (3-24 chars, lowercase alphanumeric)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be 3-24 lowercase alphanumeric characters."
  }
}

variable "replication_type" {
  description = "Storage replication type (LRS, GRS, ZRS, GZRS)"
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "ZRS", "GZRS", "RAGRS", "RAGZRS"], var.replication_type)
    error_message = "Replication type must be a valid Azure storage replication type."
  }
}

variable "enable_shared_key_access" {
  description = "Enable shared key access (disable for managed identity only)"
  type        = bool
  default     = true
}

variable "enable_versioning" {
  description = "Enable blob versioning"
  type        = bool
  default     = false
}

variable "enable_registry_container" {
  description = "Create a container for container registry storage"
  type        = bool
  default     = false
}

variable "enable_logs_container" {
  description = "Create a container for log storage"
  type        = bool
  default     = false
}

variable "enable_lifecycle_policy" {
  description = "Enable lifecycle management for backup archival"
  type        = bool
  default     = false
}

variable "blob_retention_days" {
  description = "Soft delete retention for blobs"
  type        = number
  default     = 7
}

variable "container_retention_days" {
  description = "Soft delete retention for containers"
  type        = number
  default     = 7
}

variable "backup_retention_days" {
  description = "Days before backup blobs are deleted"
  type        = number
  default     = 365
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
