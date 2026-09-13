output "id" {
  description = "PostgreSQL server ID"
  value       = azurerm_postgresql_flexible_server.this.id
}

output "name" {
  description = "PostgreSQL server name"
  value       = azurerm_postgresql_flexible_server.this.name
}

output "fqdn" {
  description = "PostgreSQL server FQDN"
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "object" {
  description = "Full PostgreSQL server object"
  value       = azurerm_postgresql_flexible_server.this
  sensitive   = true
}
