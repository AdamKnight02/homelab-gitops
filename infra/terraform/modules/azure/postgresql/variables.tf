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
    postgresql_server_name = string
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "subnet_id" {
  description = "Subnet ID for private endpoint / delegated subnet"
  type        = string
}

variable "config" {
  description = "PostgreSQL configuration object"
  type = object({
    sku_name              = optional(string, "GP_Standard_D4s_v3")
    storage_mb            = optional(number, 32768)
    backup_retention_days = optional(number, 35)
    databases             = optional(list(string), ["pki"])
    admin_username        = string
    admin_password        = string
  })
  sensitive = true
}
