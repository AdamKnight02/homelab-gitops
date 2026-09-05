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
    nsg_names = map(string)
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "network_id" {
  description = "ID of the virtual network"
  type        = string
}

variable "subnet_ids" {
  description = "Map of subnet names to IDs"
  type        = map(string)
}

variable "config" {
  description = "Security configuration object"
  type = object({
    allowed_ip_ranges    = list(string)
    enable_nsg_flow_logs = optional(bool, true)
  })
}
