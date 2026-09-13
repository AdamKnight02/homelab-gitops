# =============================================================================
# Alibaba Cloud Identity Module — Variables
# =============================================================================

variable "name" {
  description = "Name prefix for identity resources"
  type        = string
}

variable "create_ram_role" {
  description = "Whether to create a RAM role for ECS instances"
  type        = bool
  default     = true
}

variable "role_policy_arns" {
  description = "List of policy ARNs to attach to the RAM role"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
