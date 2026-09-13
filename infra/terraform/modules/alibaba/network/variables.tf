# =============================================================================
# Alibaba Cloud Network Module — Variables
# =============================================================================

variable "name" {
  description = "Name prefix for all network resources"
  type        = string
}

variable "cidr_block" {
  description = "Primary CIDR block for the VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "CIDR block must be valid."
  }
}

variable "subnets" {
  description = "Map of subnet names to CIDR blocks"
  type        = map(string)

  validation {
    condition     = alltrue([for cidr in values(var.subnets) : can(cidrhost(cidr, 0))])
    error_message = "All subnet CIDRs must be valid."
  }
}

variable "zone_ids" {
  description = "List of zone IDs for multi-zone deployment. If empty, uses first available zone."
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT gateway (cost warning: ~$30/month + data)"
  type        = bool
  default     = false
}

variable "enable_eip" {
  description = "Whether to allocate an Elastic IP for NAT gateway"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
