output "id" {
  description = "ACME container group ID"
  value       = azurerm_container_group.this.id
}

output "name" {
  description = "ACME container group name"
  value       = azurerm_container_group.this.name
}

output "fqdn" {
  description = "ACME container group FQDN"
  value       = azurerm_container_group.this.fqdn
}

output "object" {
  description = "Full ACME container group object"
  value       = azurerm_container_group.this
}
