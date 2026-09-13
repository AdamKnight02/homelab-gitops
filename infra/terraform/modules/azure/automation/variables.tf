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
    automation_account_name = string
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "identity_ids" {
  description = "List of managed identity IDs for the automation account"
  type        = list(string)
}

variable "keyvault_id" {
  description = "Key Vault ID for certificate/secret access"
  type        = string
}

variable "storage_account_name" {
  description = "Storage account name for runbook artifacts"
  type        = string
}

variable "config" {
  description = "Automation configuration object"
  type = object({
    sku_name = optional(string, "Basic")
    runbooks = optional(map(object({
      content = string
      type    = optional(string, "PowerShell")
    })), {})
    schedules = optional(map(object({
      frequency  = string
      interval   = number
      start_time = string
    })), {})
  })
}
