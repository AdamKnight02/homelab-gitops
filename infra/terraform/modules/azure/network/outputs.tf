# =============================================================================
# Azure Network Module — Outputs
# =============================================================================

output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = azurerm_virtual_network.main.name
}

output "subnet_ids" {
  description = "Map of subnet names to subnet IDs"
  value       = { for k, v in azurerm_subnet.main : k => v.id }
}

output "subnet_cidrs" {
  description = "Map of subnet names to CIDR blocks"
  value       = { for k, v in azurerm_subnet.main : k => v.address_prefixes[0] }
}

output "nat_gateway_id" {
  description = "ID of the NAT gateway (if created)"
  value       = var.enable_nat_gateway ? azurerm_nat_gateway.main[0].id : null
}

output "nat_public_ip" {
  description = "Public IP of the NAT gateway (if created)"
  value       = var.enable_nat_gateway ? azurerm_public_ip.nat[0].ip_address : null
}
