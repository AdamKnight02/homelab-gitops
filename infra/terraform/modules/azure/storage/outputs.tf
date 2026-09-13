# =============================================================================
# Azure Storage Module — Outputs
# =============================================================================

output "storage_account_id" {
  description = "ID of the storage account"
  value       = var.enable_storage_account ? azurerm_storage_account.main[0].id : null
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = var.enable_storage_account ? azurerm_storage_account.main[0].name : null
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint"
  value       = var.enable_storage_account ? azurerm_storage_account.main[0].primary_blob_endpoint : null
}

output "backup_container_name" {
  description = "Name of the backup container"
  value       = var.enable_storage_account ? azurerm_storage_container.backups[0].name : null
}

output "registry_container_name" {
  description = "Name of the registry container"
  value       = var.enable_storage_account && var.enable_registry_container ? azurerm_storage_container.registry[0].name : null
}
