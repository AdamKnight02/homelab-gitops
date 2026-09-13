# =============================================================================
# Azure Remote State Backend — Bootstrap Outputs
# =============================================================================

output "resource_group_name" {
  description = "Name of the resource group containing state infrastructure."
  value       = azurerm_resource_group.state.name
}

output "resource_group_id" {
  description = "ID of the resource group containing state infrastructure."
  value       = azurerm_resource_group.state.id
}

output "storage_account_name" {
  description = "Name of the storage account for Terraform state."
  value       = azurerm_storage_account.state.name
}

output "storage_account_id" {
  description = "ID of the storage account for Terraform state."
  value       = azurerm_storage_account.state.id
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint of the state storage account."
  value       = azurerm_storage_account.state.primary_blob_endpoint
}

output "tfstate_container_name" {
  description = "Name of the blob container for Terraform state files."
  value       = azurerm_storage_container.tfstate.name
}

output "state_backups_container_name" {
  description = "Name of the blob container for state backups."
  value       = azurerm_storage_container.state_backups.name
}

output "state_locks_container_name" {
  description = "Name of the blob container for state lock metadata."
  value       = azurerm_storage_container.state_locks.name
}

output "backend_config" {
  description = "Backend configuration for use in other Terraform modules."
  value = {
    resource_group_name  = azurerm_resource_group.state.name
    storage_account_name = azurerm_storage_account.state.name
    container_name       = azurerm_storage_container.tfstate.name
    use_azuread_auth     = true
  }
}

output "backend_config_hcl" {
  description = "Backend configuration in HCL format for backend.tf files."
  value       = <<-EOT
    resource_group_name  = "${azurerm_resource_group.state.name}"
    storage_account_name = "${azurerm_storage_account.state.name}"
    container_name       = "${azurerm_storage_container.tfstate.name}"
    use_azuread_auth     = true
  EOT
}

output "state_storage_security_notes" {
  description = "Security notes for the state storage infrastructure."
  value       = <<-EOT
    STATE STORAGE SECURITY NOTES:
    - Storage account: ${azurerm_storage_account.state.name}
    - TLS 1.2+ enforced for all connections
    - Shared key access disabled (Azure AD / RBAC only)
    - Public blob access disabled
    - Versioning enabled for state recovery
    - Soft delete enabled (${var.soft_delete_retention_days} days retention)
    - Change feed enabled for audit logging
    - Network rules: default deny, explicit allow only
    - Management lock prevents accidental deletion
    - RBAC: Storage Blob Data Contributor for Terraform SP
  EOT
}
