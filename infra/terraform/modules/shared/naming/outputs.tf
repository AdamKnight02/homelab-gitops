output "resource_group_name" {
  description = "Generated resource group name"
  value       = local.resource_group_name
}

output "vnet_name" {
  description = "Generated virtual network name"
  value       = local.vnet_name
}

output "subnet_names" {
  description = "Map of subnet names by tier"
  value       = local.subnet_names
}

output "nsg_names" {
  description = "Map of NSG names by tier"
  value       = local.nsg_names
}

output "keyvault_name" {
  description = "Generated Key Vault name"
  value       = local.keyvault_name
}

output "storage_account_name" {
  description = "Generated storage account name (no hyphens)"
  value       = local.storage_account_name
}

output "vm_name" {
  description = "Generated VM name"
  value       = local.vm_name
}

output "nic_name" {
  description = "Generated NIC name"
  value       = local.nic_name
}

output "disk_name" {
  description = "Generated disk name"
  value       = local.disk_name
}

output "gateway_name" {
  description = "Generated application gateway name"
  value       = local.gateway_name
}

output "public_ip_name" {
  description = "Generated public IP name"
  value       = local.public_ip_name
}

output "postgresql_server_name" {
  description = "Generated PostgreSQL server name"
  value       = local.postgresql_server_name
}

output "identity_names" {
  description = "Map of managed identity names by role"
  value       = local.identity_names
}

output "scep_name" {
  description = "Generated SCEP service name"
  value       = local.scep_name
}

output "acme_name" {
  description = "Generated ACME service name"
  value       = local.acme_name
}

output "automation_account_name" {
  description = "Generated automation account name"
  value       = local.automation_account_name
}

output "log_analytics_name" {
  description = "Generated Log Analytics workspace name"
  value       = local.log_analytics_name
}
