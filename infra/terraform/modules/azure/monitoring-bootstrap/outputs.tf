output "workspace_id" {
  description = "Log Analytics workspace ID"
  value       = azurerm_log_analytics_workspace.this.id
}

output "workspace_name" {
  description = "Log Analytics workspace name"
  value       = azurerm_log_analytics_workspace.this.name
}

output "object" {
  description = "Full Log Analytics workspace object"
  value       = azurerm_log_analytics_workspace.this
}
