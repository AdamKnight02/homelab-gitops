# =============================================================================
# Azure Database Module — Outputs
# =============================================================================

output "server_id" {
  description = "ID of the PostgreSQL Flexible Server"
  value       = var.database_mode != "container" ? azurerm_postgresql_flexible_server.main[0].id : null
}

output "server_fqdn" {
  description = "FQDN of the PostgreSQL Flexible Server"
  value       = var.database_mode != "container" ? azurerm_postgresql_flexible_server.main[0].fqdn : null
}

output "database_name" {
  description = "Name of the application database"
  value       = var.database_mode != "container" ? azurerm_postgresql_flexible_server_database.cadb[0].name : null
}

output "admin_username" {
  description = "PostgreSQL administrator username"
  value       = var.database_mode != "container" ? var.admin_username : null
}

output "admin_password" {
  description = "PostgreSQL administrator password"
  value       = var.database_mode != "container" ? random_password.postgres_admin[0].result : null
  sensitive   = true
}

output "connection_string" {
  description = "PostgreSQL connection string"
  value       = var.database_mode != "container" ? "postgresql://${var.admin_username}:${random_password.postgres_admin[0].result}@${azurerm_postgresql_flexible_server.main[0].fqdn}:5432/${var.database_name}?sslmode=require" : null
  sensitive   = true
}

output "ha_enabled" {
  description = "Whether HA is enabled"
  value       = var.database_mode == "azure-flexible-ha"
}
