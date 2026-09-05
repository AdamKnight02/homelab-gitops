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
    storage_account_name = string
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "config" {
  description = "Storage configuration object"
  type = object({
    account_tier             = optional(string, "Standard")
    account_replication_type = optional(string, "GRS")
    containers               = optional(list(string), ["backups", "logs", "crls"])
  })
}
