# =============================================================================
# Azure Load Balancer Module — Variables
# =============================================================================

variable "name" {
  description = "Name prefix for load balancer resources"
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

variable "lb_type" {
  description = "Load balancer type: none, basic, standard, app-gateway"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "basic", "standard", "app-gateway"], var.lb_type)
    error_message = "LB type must be one of: none, basic, standard, app-gateway."
  }
}

variable "backend_nic_ids" {
  description = "List of NIC IDs to add to the backend pool"
  type        = list(string)
  default     = []
}

variable "availability_zones" {
  description = "Number of availability zones (0 = no zones)"
  type        = number
  default     = 0
}

variable "app_gateway_subnet_id" {
  description = "Subnet ID for Application Gateway (required if lb_type = app-gateway)"
  type        = string
  default     = ""
}

variable "app_gateway_capacity" {
  description = "Application Gateway capacity (instance count)"
  type        = number
  default     = 2
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
