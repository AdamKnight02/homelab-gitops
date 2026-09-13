# =============================================================================
# Azure Monitoring Bootstrap Module — Variables
# =============================================================================

variable "name" {
  description = "Name prefix for monitoring resources"
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

variable "enable_log_analytics" {
  description = "Whether to create a Log Analytics workspace"
  type        = bool
  default     = false
}

variable "enable_app_insights" {
  description = "Whether to create Application Insights"
  type        = bool
  default     = false
}

variable "retention_days" {
  description = "Log Analytics retention in days"
  type        = number
  default     = 30
}

variable "vm_ids" {
  description = "List of VM IDs for diagnostic settings"
  type        = list(string)
  default     = []
}

variable "nsg_id" {
  description = "NSG ID for diagnostic settings"
  type        = string
  default     = ""
}

variable "enable_nsg_diagnostics" {
  description = "Enable NSG diagnostic settings"
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Email address for alert notifications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
