resource "azurerm_container_group" "this" {
  name                = var.naming.acme_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  ip_address_type     = "Private"
  tags                = var.tags

  container {
    name   = var.naming.acme_name
    image  = var.config.image
    cpu    = var.config.cpu
    memory = var.config.memory_gb

    ports {
      port     = var.config.port
      protocol = "TCP"
    }

    environment_variables = {
      ACME_PORT          = tostring(var.config.port)
      ACME_DIRECTORY_URL = var.config.directory_url
      POSTGRESQL_FQDN    = var.postgresql_fqdn
      KEYVAULT_ID        = var.keyvault_id
    }
  }
}
