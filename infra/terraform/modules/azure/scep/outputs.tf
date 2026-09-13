output "id" {
  description = "SCEP container group ID"
  value       = azurerm_container_group.this.id
}

output "name" {
  description = "SCEP container group name"
  value       = azurerm_container_group.this.name
}

output "fqdn" {
  description = "SCEP container group FQDN"
  value       = azurerm_container_group.this.fqdn
}

output "object" {
  description = "Full SCEP container group object"
  value       = azurerm_container_group.this
}
