output "nsg_ids" {
  description = "Map of NSG names to IDs"
  value       = { for k, v in azurerm_network_security_group.this : k => v.id }
}

output "object" {
  description = "Full NSG objects"
  value       = azurerm_network_security_group.this
}
