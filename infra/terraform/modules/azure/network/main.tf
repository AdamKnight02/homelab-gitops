resource "azurerm_virtual_network" "this" {
  name                = var.naming.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.config.vnet_address_space
  dns_servers         = var.config.dns_servers
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  for_each = var.config.subnets

  name                 = lookup(var.naming.subnet_names, each.key, each.key)
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = each.value.address_prefixes
  service_endpoints    = each.value.service_endpoints
}
