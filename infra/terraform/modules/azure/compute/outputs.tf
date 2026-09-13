# =============================================================================
# Azure Compute Module — Outputs
# =============================================================================

output "vm_ids" {
  description = "List of VM IDs"
  value       = azurerm_linux_virtual_machine.vm[*].id
}

output "vm_names" {
  description = "List of VM names"
  value       = azurerm_linux_virtual_machine.vm[*].name
}

output "vm_private_ips" {
  description = "List of private IP addresses"
  value       = azurerm_linux_virtual_machine.vm[*].private_ip_address
}

output "vm_public_ips" {
  description = "List of public IP addresses (if allocated)"
  value       = var.enable_public_ip ? azurerm_public_ip.vm[*].ip_address : []
}

output "nic_ids" {
  description = "List of network interface IDs"
  value       = azurerm_network_interface.vm[*].id
}

output "data_disk_ids" {
  description = "List of data disk IDs (if created)"
  value       = var.enable_data_disks ? azurerm_managed_disk.data[*].id : []
}
