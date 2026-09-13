# =============================================================================
# Azure Load Balancer Module — Outputs
# =============================================================================

output "lb_id" {
  description = "ID of the load balancer"
  value       = var.lb_type != "none" && var.lb_type != "app-gateway" ? azurerm_lb.main[0].id : null
}

output "lb_public_ip" {
  description = "Public IP of the load balancer"
  value       = var.lb_type != "none" ? azurerm_public_ip.lb[0].ip_address : null
}

output "lb_fqdn" {
  description = "FQDN of the load balancer public IP"
  value       = var.lb_type != "none" ? azurerm_public_ip.lb[0].fqdn : null
}

output "backend_pool_id" {
  description = "ID of the backend address pool"
  value       = var.lb_type != "none" && var.lb_type != "app-gateway" ? azurerm_lb_backend_address_pool.main[0].id : null
}

output "app_gateway_id" {
  description = "ID of the Application Gateway"
  value       = var.lb_type == "app-gateway" ? azurerm_application_gateway.main[0].id : null
}
