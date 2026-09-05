output "id" {
  description = "Application Gateway ID"
  value       = azurerm_application_gateway.this.id
}

output "name" {
  description = "Application Gateway name"
  value       = azurerm_application_gateway.this.name
}

output "public_ip" {
  description = "Public IP address of the gateway"
  value       = azurerm_public_ip.this.ip_address
}

output "object" {
  description = "Full Application Gateway object"
  value       = azurerm_application_gateway.this
}
