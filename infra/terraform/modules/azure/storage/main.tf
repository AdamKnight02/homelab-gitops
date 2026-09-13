# =============================================================================
# Azure Storage Module — Main Resources
# =============================================================================
# Creates Azure Storage Account for blob storage, backups, and container
# registry. Standard/Enterprise tiers only.
# =============================================================================

# ---------------------------------------------------------------------------
# Storage Account
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "main" {
  count = var.enable_storage_account ? 1 : 0

  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.replication_type
  account_kind             = "StorageV2"

  # Security hardening
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = var.enable_shared_key_access

  # Enable blob encryption
  blob_properties {
    delete_retention_policy {
      days = var.blob_retention_days
    }
    container_delete_retention_policy {
      days = var.container_retention_days
    }
    versioning_enabled = var.enable_versioning
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Blob Containers
# ---------------------------------------------------------------------------
resource "azurerm_storage_container" "backups" {
  count = var.enable_storage_account ? 1 : 0

  name                  = "backups"
  storage_account_name  = azurerm_storage_account.main[0].name
  container_access_type = "private"
}

resource "azurerm_storage_container" "registry" {
  count = var.enable_storage_account && var.enable_registry_container ? 1 : 0

  name                  = "registry"
  storage_account_name  = azurerm_storage_account.main[0].name
  container_access_type = "private"
}

resource "azurerm_storage_container" "logs" {
  count = var.enable_storage_account && var.enable_logs_container ? 1 : 0

  name                  = "logs"
  storage_account_name  = azurerm_storage_account.main[0].name
  container_access_type = "private"
}

# ---------------------------------------------------------------------------
# Lifecycle Management Policy
# ---------------------------------------------------------------------------
resource "azurerm_storage_management_policy" "main" {
  count = var.enable_storage_account && var.enable_lifecycle_policy ? 1 : 0

  storage_account_id = azurerm_storage_account.main[0].id

  rule {
    name    = "archive-old-backups"
    enabled = true

    filters {
      prefix_match = ["backups/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_archive_after_days_since_modification_greater_than = 90
        delete_after_days_since_modification_greater_than          = var.backup_retention_days
      }
    }
  }
}
