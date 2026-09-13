resource "azurerm_postgresql_flexible_server" "this" {
  name                   = var.naming.postgresql_server_name
  resource_group_name    = var.resource_group_name
  location               = var.location
  administrator_login    = var.config.admin_username
  administrator_password = var.config.admin_password
  sku_name               = var.config.sku_name
  storage_mb             = var.config.storage_mb
  backup_retention_days  = var.config.backup_retention_days
  version                = "16"
  delegated_subnet_id    = var.subnet_id
  private_dns_zone_id    = azurerm_private_dns_zone.postgresql.id
  tags                   = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgresql]
}

resource "azurerm_postgresql_flexible_server_database" "this" {
  for_each = toset(var.config.databases)

  name      = each.value
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Private DNS zone for PostgreSQL
resource "azurerm_private_dns_zone" "postgresql" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  name                  = "${var.naming.postgresql_server_name}-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgresql.name
  virtual_network_id    = var.subnet_id != "" ? split("/subnets/", var.subnet_id)[0] : ""
  tags                  = var.tags
}
