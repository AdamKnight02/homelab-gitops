# =============================================================================
# Azure Identity Module — Main Resources
# =============================================================================
# Creates User-Assigned Managed Identities for VMs and AKS.
# Standard/Enterprise tiers use managed identity for Key Vault, Storage, etc.
# =============================================================================

# ---------------------------------------------------------------------------
# User-Assigned Managed Identity
# ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "main" {
  count = var.enable_managed_identity ? 1 : 0

  name                = "${var.name}-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Role Assignment: Key Vault Secrets User (if Key Vault enabled)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "key_vault_secrets" {
  count = var.enable_managed_identity && var.enable_key_vault_role ? 1 : 0

  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.main[0].principal_id
}

# ---------------------------------------------------------------------------
# Role Assignment: Storage Blob Data Contributor (if Storage enabled)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "storage_blob" {
  count = var.enable_managed_identity && var.enable_storage_role ? 1 : 0

  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.main[0].principal_id
}

# ---------------------------------------------------------------------------
# Role Assignment: AcrPull (if ACR enabled)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "acr_pull" {
  count = var.enable_managed_identity && var.enable_acr_role ? 1 : 0

  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.main[0].principal_id
}
