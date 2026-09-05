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
    scep_name = string
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "gateway_id" {
  description = "Application Gateway ID for backend pool association"
  type        = string
}

variable "keyvault_id" {
  description = "Key Vault ID for certificate access"
  type        = string
}

variable "postgresql_fqdn" {
  description = "PostgreSQL server FQDN for metadata"
  type        = string
}

variable "config" {
  description = "SCEP service configuration object"
  type = object({
    image              = string
    cpu                = optional(number, 2)
    memory_gb          = optional(number, 4)
    port               = optional(number, 8080)
    challenge_password = string
  })
  sensitive = true
}
