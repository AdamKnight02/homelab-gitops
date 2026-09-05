resource "azurerm_storage_account" "this" {
  name                     = var.naming.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.config.account_tier
  account_replication_type = var.config.account_replication_type
  tags                     = var.tags

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }
  }
}

resource "azurerm_storage_container" "this" {
  for_each = toset(var.config.containers)

  name                  = each.value
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}
