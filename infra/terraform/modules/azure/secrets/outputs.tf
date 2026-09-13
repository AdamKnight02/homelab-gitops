# =============================================================================
# Azure Secrets Module — Outputs
# =============================================================================

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = var.enable_key_vault ? azurerm_key_vault.main[0].id : null
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = var.enable_key_vault ? azurerm_key_vault.main[0].name : null
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = var.enable_key_vault ? azurerm_key_vault.main[0].vault_uri : null
}

output "ca_signing_key_id" {
  description = "ID of the CA signing key"
  value       = var.enable_key_vault && var.enable_ca_keys ? azurerm_key_vault_key.ca_signing[0].id : null
}

output "ocsp_signing_key_id" {
  description = "ID of the OCSP signing key"
  value       = var.enable_key_vault && var.enable_ca_keys ? azurerm_key_vault_key.ocsp_signing[0].id : null
}
