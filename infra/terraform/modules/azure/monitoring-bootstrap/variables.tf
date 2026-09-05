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
    log_analytics_name = string
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "config" {
  description = "Monitoring configuration object"
  type = object({
    retention_in_days = optional(number, 30)
    alerts = optional(map(object({
      metric_name = string
      threshold   = number
      severity    = optional(number, 2)
    })), {})
  })
}
