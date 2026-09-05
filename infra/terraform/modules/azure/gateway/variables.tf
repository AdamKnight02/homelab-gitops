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
    gateway_name   = string
    public_ip_name = string
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "subnet_id" {
  description = "Subnet ID for the application gateway"
  type        = string
}

variable "keyvault_id" {
  description = "Key Vault ID for SSL certificates"
  type        = string
}

variable "config" {
  description = "Gateway configuration object"
  type = object({
    sku_name = optional(string, "WAF_v2")
    sku_tier = optional(string, "WAF_v2")
    capacity = optional(number, 2)
    ssl_certificates = optional(map(object({
      keyvault_secret_id = string
    })), {})
  })
}
