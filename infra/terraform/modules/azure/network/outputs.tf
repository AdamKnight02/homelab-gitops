output "vnet_id" {
  description = "Virtual network ID"
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Virtual network name"
  value       = azurerm_virtual_network.this.name
}

output "subnet_ids" {
  description = "Map of subnet names to IDs"
  value       = { for k, v in azurerm_subnet.this : k => v.id }
}

output "object" {
  description = "Full network objects"
  value = {
    vnet    = azurerm_virtual_network.this
    subnets = azurerm_subnet.this
  }
}
