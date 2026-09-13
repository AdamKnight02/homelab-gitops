# =============================================================================
# Azure Secrets Module — Main Resources
# =============================================================================
# Creates Azure Key Vault for secrets, keys, and certificate management.
# Enterprise tier only. Standard tier uses OpenBao on K3s instead.
# =============================================================================

# ---------------------------------------------------------------------------
# Current Client Config
# ---------------------------------------------------------------------------
data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# Key Vault
# ---------------------------------------------------------------------------
resource "azurerm_key_vault" "main" {
  count = var.enable_key_vault ? 1 : 0

  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = var.sku_name

  # Security hardening
  enabled_for_deployment          = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true
  rbac_authorization_enabled      = true

  # Soft delete and purge protection (required for production)
  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled

  # Network ACLs — deny by default, allow specific networks
  network_acls {
    default_action             = var.network_default_action
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = var.allowed_subnet_ids
    ip_rules                   = var.allowed_ip_ranges
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Key Vault Keys for CA operations
# ---------------------------------------------------------------------------
resource "azurerm_key_vault_key" "ca_signing" {
  count = var.enable_key_vault && var.enable_ca_keys ? 1 : 0

  name         = "ca-signing-key"
  key_vault_id = azurerm_key_vault.main[0].id
  key_type     = "RSA"
  key_size     = 4096

  key_opts = [
    "sign",
    "verify",
  ]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }
    expire_after         = "P365D"
    notify_before_expiry = "P30D"
  }
}

resource "azurerm_key_vault_key" "ocsp_signing" {
  count = var.enable_key_vault && var.enable_ca_keys ? 1 : 0

  name         = "ocsp-signing-key"
  key_vault_id = azurerm_key_vault.main[0].id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "sign",
    "verify",
  ]
}

# ---------------------------------------------------------------------------
# Key Vault Secrets for database credentials
# ---------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "db_connection_string" {
  count = var.enable_key_vault && var.db_connection_string != "" ? 1 : 0

  name         = "db-connection-string"
  value        = var.db_connection_string
  key_vault_id = azurerm_key_vault.main[0].id
  tags         = var.tags
}

resource "azurerm_key_vault_secret" "openbao_unseal_key" {
  count = var.enable_key_vault && var.enable_openbao_auto_unseal ? 1 : 0

  name         = "openbao-unseal-key"
  value        = "placeholder-replaced-by-openbao"
  key_vault_id = azurerm_key_vault.main[0].id
  tags         = var.tags

  lifecycle {
    ignore_changes = [value]
  }
}
