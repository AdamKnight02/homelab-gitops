# =============================================================================
# Azure Database Module — Main Resources
# =============================================================================
# Creates Azure Database for PostgreSQL Flexible Server.
# Standard: Burstable single server. Enterprise: General Purpose with HA.
# =============================================================================

# ---------------------------------------------------------------------------
# Random Password for PostgreSQL Admin
# ---------------------------------------------------------------------------
resource "random_password" "postgres_admin" {
  count = var.database_mode != "container" ? 1 : 0

  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ---------------------------------------------------------------------------
# PostgreSQL Flexible Server
# ---------------------------------------------------------------------------
resource "azurerm_postgresql_flexible_server" "main" {
  count = var.database_mode != "container" ? 1 : 0

  name                   = "${var.name}-psql"
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = var.postgres_version
  administrator_login    = var.admin_username
  administrator_password = random_password.postgres_admin[0].result

  sku_name   = var.sku_name
  storage_mb = var.storage_mb

  # High Availability (Enterprise only)
  dynamic "high_availability" {
    for_each = var.database_mode == "azure-flexible-ha" ? [1] : []
    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = var.ha_standby_zone
    }
  }

  # Backup configuration
  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.database_mode == "azure-flexible-ha" ? true : false

  # Network — private endpoint for enterprise, public for standard (cost)
  public_network_access_enabled = var.database_mode == "azure-flexible" ? true : false

  # Delegated subnet for private access (enterprise only)
  delegated_subnet_id = var.database_mode == "azure-flexible-ha" && var.delegated_subnet_id != "" ? var.delegated_subnet_id : null
  private_dns_zone_id = var.database_mode == "azure-flexible-ha" && var.private_dns_zone_id != "" ? var.private_dns_zone_id : null

  tags = var.tags

  lifecycle {
    ignore_changes = [
      zone,
      high_availability[0].standby_availability_zone,
    ]
  }
}

# ---------------------------------------------------------------------------
# PostgreSQL Database
# ---------------------------------------------------------------------------
resource "azurerm_postgresql_flexible_server_database" "cadb" {
  count = var.database_mode != "container" ? 1 : 0

  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.main[0].id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# ---------------------------------------------------------------------------
# Firewall Rule (Standard tier — allow Azure services)
# ---------------------------------------------------------------------------
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  count = var.database_mode == "azure-flexible" ? 1 : 0

  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.main[0].id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# ---------------------------------------------------------------------------
# Private DNS Zone (Enterprise only)
# ---------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "postgres" {
  count = var.database_mode == "azure-flexible-ha" && var.enable_private_dns ? 1 : 0

  name                = "${var.name}.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  count = var.database_mode == "azure-flexible-ha" && var.enable_private_dns ? 1 : 0

  name                  = "${var.name}-psql-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres[0].name
  virtual_network_id    = var.vnet_id
  tags                  = var.tags
}
