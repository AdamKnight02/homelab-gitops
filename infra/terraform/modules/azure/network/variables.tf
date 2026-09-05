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
    vnet_name    = string
    subnet_names = map(string)
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "config" {
  description = "Network configuration object"
  type = object({
    vnet_address_space = list(string)
    subnets = map(object({
      address_prefixes  = list(string)
      service_endpoints = optional(list(string), [])
    }))
    dns_servers = optional(list(string), [])
  })
}
