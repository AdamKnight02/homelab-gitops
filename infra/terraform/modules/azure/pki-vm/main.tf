module "vm" {
  source = "../vm"

  resource_group_name = var.resource_group_name
  location            = var.location
  naming = {
    vm_name  = var.naming.vm_name
    nic_name = var.naming.nic_name
  }
  tags         = var.tags
  subnet_id    = var.subnet_id
  identity_ids = var.identity_ids
  config = {
    vm_size         = var.config.vm_size
    admin_username  = var.config.admin_username
    os_disk_size_gb = var.config.os_disk_size_gb
  }
}

resource "azurerm_managed_disk" "data" {
  name                 = var.naming.disk_name
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.config.data_disk_size_gb
  tags                 = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  managed_disk_id    = azurerm_managed_disk.data.id
  virtual_machine_id = module.vm.id
  lun                = 0
  caching            = "ReadWrite"
}
