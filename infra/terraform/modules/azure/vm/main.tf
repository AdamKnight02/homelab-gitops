resource "azurerm_network_interface" "this" {
  name                = var.naming.nic_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "this" {
  name                = var.naming.vm_name
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.config.vm_size
  admin_username      = var.config.admin_username
  tags                = var.tags

  network_interface_ids = [
    azurerm_network_interface.this.id,
  ]

  admin_ssh_key {
    username   = var.config.admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.config.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.config.image_reference.publisher
    offer     = var.config.image_reference.offer
    sku       = var.config.image_reference.sku
    version   = var.config.image_reference.version
  }

  identity {
    type         = "UserAssigned"
    identity_ids = var.identity_ids
  }
}
