# =============================================================================
# Azure Database Module — Variables
# =============================================================================

variable "name" {
  description = "Name prefix for database resources"
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

variable "database_mode" {
  description = "Database deployment mode: container, azure-flexible, azure-flexible-ha"
  type        = string
  default     = "container"

  validation {
    condition     = contains(["container", "azure-flexible", "azure-flexible-ha"], var.database_mode)
    error_message = "Database mode must be one of: container, azure-flexible, azure-flexible-ha."
  }
}

variable "sku_name" {
  description = "Azure Database for PostgreSQL SKU"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Storage size in MB"
  type        = number
  default     = 32768
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "16"
}

variable "admin_username" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "psqladmin"
}

variable "database_name" {
  description = "Name of the application database"
  type        = string
  default     = "cadb"
}

variable "backup_retention_days" {
  description = "Backup retention in days"
  type        = number
  default     = 7
}

variable "ha_standby_zone" {
  description = "Availability zone for HA standby"
  type        = string
  default     = "2"
}

variable "delegated_subnet_id" {
  description = "Subnet ID for private endpoint (enterprise)"
  type        = string
  default     = ""
}

variable "enable_private_dns" {
  description = "Enable private DNS zone for PostgreSQL"
  type        = bool
  default     = false
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID (enterprise)"
  type        = string
  default     = ""
}

variable "vnet_id" {
  description = "VNet ID for DNS zone link"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
