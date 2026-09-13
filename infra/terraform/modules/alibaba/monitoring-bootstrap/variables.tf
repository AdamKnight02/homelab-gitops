# =============================================================================
# Alibaba Cloud Monitoring Bootstrap Module — Variables
# =============================================================================

variable "name" {
  description = "Name prefix for monitoring resources"
  type        = string
}

variable "enable_cloudmonitor" {
  description = "Enable Alibaba Cloud CloudMonitor integration"
  type        = bool
  default     = false
}

variable "enable_prometheus" {
  description = "Enable Prometheus monitoring stack"
  type        = bool
  default     = false
}

variable "enable_grafana" {
  description = "Enable Grafana dashboards"
  type        = bool
  default     = false
}

variable "prometheus_retention_days" {
  description = "Prometheus data retention in days"
  type        = number
  default     = 7

  validation {
    condition     = var.prometheus_retention_days >= 1 && var.prometheus_retention_days <= 365
    error_message = "Retention must be between 1 and 365 days."
  }
}

variable "grafana_admin_password" {
  description = "Grafana admin password (sensitive)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
