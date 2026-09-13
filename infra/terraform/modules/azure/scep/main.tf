resource "azurerm_container_group" "this" {
  name                = var.naming.scep_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  ip_address_type     = "Private"
  tags                = var.tags

  container {
    name   = var.naming.scep_name
    image  = var.config.image
    cpu    = var.config.cpu
    memory = var.config.memory_gb

    ports {
      port     = var.config.port
      protocol = "TCP"
    }

    environment_variables = {
      SCEP_PORT       = tostring(var.config.port)
      POSTGRESQL_FQDN = var.postgresql_fqdn
      KEYVAULT_ID     = var.keyvault_id
    }

    secure_environment_variables = {
      SCEP_CHALLENGE_PASSWORD = var.config.challenge_password
    }
  }
}
