resource "azurerm_key_vault" "this" {
  name                        = var.naming.keyvault_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = var.tenant_id
  sku_name                    = var.config.sku_name
  enabled_for_disk_encryption = var.config.enabled_for_disk_encryption
  purge_protection_enabled    = var.config.purge_protection_enabled
  soft_delete_retention_days  = var.config.soft_delete_retention_days
  tags                        = var.tags
}

resource "azurerm_key_vault_access_policy" "this" {
  for_each = var.object_ids

  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = var.tenant_id
  object_id    = each.value

  key_permissions = [
    "Get", "List", "Create", "Delete", "Update",
    "Encrypt", "Decrypt", "Sign", "Verify",
    "WrapKey", "UnwrapKey",
  ]

  secret_permissions = [
    "Get", "List", "Set", "Delete",
  ]

  certificate_permissions = [
    "Get", "List", "Create", "Delete", "Update",
    "Import", "ManageContacts", "ManageIssuers",
    "GetIssuers", "ListIssuers", "SetIssuers", "DeleteIssuers",
  ]
}
