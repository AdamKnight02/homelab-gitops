output "id" {
  description = "Resource group ID"
  value       = azurerm_resource_group.this.id
}

output "name" {
  description = "Resource group name"
  value       = azurerm_resource_group.this.name
}

output "location" {
  description = "Resource group location"
  value       = azurerm_resource_group.this.location
}

output "object" {
  description = "Full resource group object"
  value       = azurerm_resource_group.this
}
