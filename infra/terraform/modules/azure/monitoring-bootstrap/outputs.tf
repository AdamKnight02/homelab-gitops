# =============================================================================
# Azure Monitoring Bootstrap Module — Outputs
# =============================================================================

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = var.enable_log_analytics ? azurerm_log_analytics_workspace.main[0].id : null
}

output "log_analytics_workspace_key" {
  description = "Primary shared key for Log Analytics"
  value       = var.enable_log_analytics ? azurerm_log_analytics_workspace.main[0].primary_shared_key : null
  sensitive   = true
}

output "app_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = var.enable_app_insights ? azurerm_application_insights.main[0].instrumentation_key : null
  sensitive   = true
}

output "app_insights_connection_string" {
  description = "Application Insights connection string"
  value       = var.enable_app_insights ? azurerm_application_insights.main[0].connection_string : null
  sensitive   = true
}

output "action_group_id" {
  description = "ID of the alert action group"
  value       = var.enable_log_analytics && var.alert_email != "" ? azurerm_monitor_action_group.main[0].id : null
}
