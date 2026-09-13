# =============================================================================
# Azure Compute Module — Main Resources
# =============================================================================
# Creates VMs with tier-aware configuration. Supports single-node (economy)
# through multi-zone (enterprise) deployments.
# =============================================================================

# ---------------------------------------------------------------------------
# Public IPs (optional — per-VM)
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "vm" {
  count = var.enable_public_ip ? var.instance_count : 0

  name                = "${var.name}-pip-${count.index}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.availability_zones > 0 ? [tostring((count.index % var.availability_zones) + 1)] : null
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Network Interfaces
# ---------------------------------------------------------------------------
resource "azurerm_network_interface" "vm" {
  count = var.instance_count

  name                = "${var.name}-nic-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = var.use_static_private_ips ? "Static" : "Dynamic"
    private_ip_address            = var.use_static_private_ips ? cidrhost(var.subnet_cidr, 4 + count.index) : null
    public_ip_address_id          = var.enable_public_ip ? azurerm_public_ip.vm[count.index].id : null
  }
}

# ---------------------------------------------------------------------------
# Linux Virtual Machines
# ---------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "vm" {
  count = var.instance_count

  name                            = "${var.name}-vm-${count.index}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.vm[count.index].id]
  zone                            = var.availability_zones > 0 ? tostring((count.index % var.availability_zones) + 1) : null
  tags = merge(var.tags, {
    Role  = count.index == 0 ? "control-plane" : "worker"
    Index = tostring(count.index)
  })

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "${var.name}-osdisk-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.os_image.publisher
    offer     = var.os_image.offer
    sku       = var.os_image.sku
    version   = var.os_image.version
  }

  # Managed Identity
  dynamic "identity" {
    for_each = var.managed_identity_id != "" ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = [var.managed_identity_id]
    }
  }

  # Cloud-init
  custom_data = base64encode(var.cloud_init_configs[count.index])

  lifecycle {
    ignore_changes = [
      custom_data,
    ]
  }
}

# ---------------------------------------------------------------------------
# Data Disks (Standard/Enterprise tiers)
# ---------------------------------------------------------------------------
resource "azurerm_managed_disk" "data" {
  count = var.enable_data_disks ? var.instance_count : 0

  name                 = "${var.name}-datadisk-${count.index}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = var.data_disk_type
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
  zone                 = var.availability_zones > 0 ? tostring((count.index % var.availability_zones) + 1) : null
  tags                 = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  count = var.enable_data_disks ? var.instance_count : 0

  managed_disk_id    = azurerm_managed_disk.data[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.vm[count.index].id
  lun                = 0
  caching            = "ReadWrite"
}
