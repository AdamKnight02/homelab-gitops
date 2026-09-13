# =============================================================================
# Azure Security Module — Variables
# =============================================================================

variable "name" {
  description = "Name prefix for security resources"
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

variable "subnet_ids" {
  description = "Map of subnet names to subnet IDs for NSG association"
  type        = map(string)
}

variable "allow_ssh_cidr" {
  description = "CIDR blocks allowed to SSH to VMs"
  type        = list(string)
  default     = []
}

variable "enable_k3s_ha" {
  description = "Enable K3s HA rules (multi-node cluster communication)"
  type        = bool
  default     = false
}

variable "enable_load_balancer" {
  description = "Enable LB health probe rules"
  type        = bool
  default     = false
}

variable "enable_ingress" {
  description = "Enable HTTP/HTTPS ingress rules"
  type        = bool
  default     = false
}

variable "enable_nodeport" {
  description = "Enable NodePort range rules (economy tier without LB)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
