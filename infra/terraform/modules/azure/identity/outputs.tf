# =============================================================================
# Azure Identity Module — Outputs
# =============================================================================

output "identity_id" {
  description = "ID of the user-assigned managed identity"
  value       = var.enable_managed_identity ? azurerm_user_assigned_identity.main[0].id : null
}

output "identity_principal_id" {
  description = "Principal ID of the managed identity"
  value       = var.enable_managed_identity ? azurerm_user_assigned_identity.main[0].principal_id : null
}

output "identity_client_id" {
  description = "Client ID of the managed identity"
  value       = var.enable_managed_identity ? azurerm_user_assigned_identity.main[0].client_id : null
}
