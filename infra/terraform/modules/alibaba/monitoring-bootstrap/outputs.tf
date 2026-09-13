# =============================================================================
# Alibaba Cloud Monitoring Bootstrap Module — Outputs
# =============================================================================

output "prometheus_values" {
  description = "Prometheus Helm values"
  value       = local.prometheus_values
}

output "grafana_values" {
  description = "Grafana Helm values"
  value       = local.grafana_values
  sensitive   = true
}

output "cloudmonitor_enabled" {
  description = "Whether CloudMonitor is enabled"
  value       = var.enable_cloudmonitor
}
