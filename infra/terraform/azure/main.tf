# =============================================================================
# Azure Root Module — Main Resources
# =============================================================================
# This module defines the Azure infrastructure for the PKI platform.
# Tier-driven: economy uses inline resources (backward compatible);
# standard/enterprise use shared modules for expanded capabilities.
#
# DESIGN: The existing economy-tier resources are preserved as-is.
# Standard and enterprise tiers add resources AROUND the existing pattern.
# =============================================================================

# ---------------------------------------------------------------------------
# Economy Tier Guardrail
# ---------------------------------------------------------------------------
# Fail fast if economy tier has forbidden resources enabled.
resource "terraform_data" "economy_guardrail" {
  count = local.tier == "economy" && length(local.economy_violations) > 0 ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(local.economy_violations) == 0
      error_message = "ECONOMY TIER VIOLATION: The following resources are not allowed in economy tier: ${join(", ", local.economy_violations)}. Economy tier is single-VM K3s with no managed services."
    }
  }
}

# ---------------------------------------------------------------------------
# Resource Group
# All resources are grouped for easy lifecycle management.
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.azure_region
  tags     = local.common_tags
}

# ---------------------------------------------------------------------------
# Virtual Network
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = local.vnet_name
  address_space       = [var.network_cidr]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.network_tags
}

# ---------------------------------------------------------------------------
# Subnets (tier-aware: economy/standard get 1, enterprise gets 2)
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "main" {
  for_each = local.subnets

  name                 = each.key == "main" ? local.subnet_name : "${local.name_prefix}-${each.key}-${local.name_suffix}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value]
}

# ---------------------------------------------------------------------------
# Network Security Group
# Default: deny all inbound. SSH only if allow_ssh_cidr is specified.
# Tier-aware: standard/enterprise get additional rules for K3s HA and LB.
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "main" {
  name                = local.nsg_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.security_tags

  # SSH access — only if explicitly allowed
  dynamic "security_rule" {
    for_each = length(var.allow_ssh_cidr) > 0 ? [1] : []
    content {
      name                       = "AllowSSH"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefixes    = var.allow_ssh_cidr
      destination_address_prefix = "*"
    }
  }

  # K3s API server — internal only (for multi-node, standard/enterprise)
  dynamic "security_rule" {
    for_each = local.vm_count > 1 ? [1] : []
    content {
      name                       = "AllowK3sAPI"
      priority                   = 200
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "6443"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "*"
    }
  }

  # K3s etcd — internal only (for HA control plane)
  dynamic "security_rule" {
    for_each = local.vm_count > 1 ? [1] : []
    content {
      name                       = "AllowK3sEtcd"
      priority                   = 210
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["2379", "2380"]
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "*"
    }
  }

  # K3s flannel VXLAN — internal only
  dynamic "security_rule" {
    for_each = local.vm_count > 1 ? [1] : []
    content {
      name                       = "AllowK3sFlannel"
      priority                   = 220
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Udp"
      source_port_range          = "*"
      destination_port_range     = "8472"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "*"
    }
  }

  # K3s kubelet — internal only
  dynamic "security_rule" {
    for_each = local.vm_count > 1 ? [1] : []
    content {
      name                       = "AllowK3sKubelet"
      priority                   = 230
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "10250"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "*"
    }
  }

  # Load Balancer health probes — only when LB is enabled
  dynamic "security_rule" {
    for_each = local.load_balancer_type != "none" ? [1] : []
    content {
      name                       = "AllowLBHealthProbe"
      priority                   = 300
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "6443"
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "*"
    }
  }

  # HTTP/HTTPS ingress — only when LB or App Gateway is enabled
  dynamic "security_rule" {
    for_each = local.load_balancer_type != "none" ? [1] : []
    content {
      name                       = "AllowHTTP"
      priority                   = 310
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }

  dynamic "security_rule" {
    for_each = local.load_balancer_type != "none" ? [1] : []
    content {
      name                       = "AllowHTTPS"
      priority                   = 320
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }

  # NodePort range — for economy tier without LB
  dynamic "security_rule" {
    for_each = local.load_balancer_type == "none" && local.tier == "economy" ? [1] : []
    content {
      name                       = "AllowNodePort"
      priority                   = 400
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "30000-32767"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }

  # Deny all other inbound (implicit, but explicit for clarity)
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ---------------------------------------------------------------------------
# NSG-Subnet Associations
# ---------------------------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "main" {
  for_each = azurerm_subnet.main

  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# ---------------------------------------------------------------------------
# Public IP (optional — disabled by default for cost/security)
# Economy: single VM. Standard/Enterprise: per-VM via compute module.
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "main" {
  count = var.azure_public_ip_enabled && local.tier == "economy" ? 1 : 0

  name                = local.public_ip_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# ---------------------------------------------------------------------------
# ECONOMY TIER: Single VM (existing pattern — preserved)
# ---------------------------------------------------------------------------
resource "azurerm_network_interface" "main" {
  count = local.tier == "economy" ? 1 : 0

  name                = local.nic_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.network_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main["main"].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.azure_public_ip_enabled ? azurerm_public_ip.main[0].id : null
  }
}

resource "azurerm_linux_virtual_machine" "main" {
  count = local.tier == "economy" ? 1 : 0

  name                            = local.vm_name
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = local.vm_size
  admin_username                  = var.azure_admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.main[0].id]
  tags                            = local.compute_tags

  admin_ssh_key {
    username   = var.azure_admin_username
    public_key = var.azure_ssh_public_key != "" ? var.azure_ssh_public_key : tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    name                 = local.os_disk_name
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.azure_os_disk_size_gb
  }

  source_image_reference {
    publisher = var.azure_vm_os.publisher
    offer     = var.azure_vm_os.offer
    sku       = var.azure_vm_os.sku
    version   = var.azure_vm_os.version
  }

  # Cloud-init for K3s + Argo CD bootstrap
  custom_data = base64encode(local.cloud_init_config)

  lifecycle {
    ignore_changes = [
      custom_data,
    ]
  }
}

# ---------------------------------------------------------------------------
# STANDARD / ENTERPRISE TIER: Multi-VM via Compute Module
# ---------------------------------------------------------------------------
module "kubernetes_bootstrap" {
  count = local.tier != "economy" ? 1 : 0

  source = "../modules/azure/kubernetes-bootstrap"

  name                = local.name_prefix
  instance_count      = local.vm_count
  admin_username      = var.azure_admin_username
  ssh_public_key      = var.azure_ssh_public_key != "" ? var.azure_ssh_public_key : tls_private_key.ssh.public_key_openssh
  k3s_version         = var.k3s_version
  argocd_version      = var.argocd_version
  git_repo_url        = var.git_repo_url
  git_target_revision = var.git_target_revision
  # Use a predictable IP for the first server node to avoid circular dependency.
  # Azure assigns the first available IP in the subnet (.4) by default.
  server_private_ip     = cidrhost(var.subnet_cidr, 4)
  k3s_token             = local.k3s_token_resolved
  enable_azure_csi      = var.enable_azure_csi
  enable_azure_ccm      = var.enable_azure_ccm
  azure_tenant_id       = var.azure_tenant_id
  azure_subscription_id = var.azure_subscription_id
  azure_resource_group  = local.resource_group_name
  azure_vnet_name       = local.vnet_name
  azure_subnet_name     = local.subnet_name
  azure_nsg_name        = local.nsg_name
  azure_lb_name         = local.load_balancer_type != "none" ? "${local.name_prefix}-lb" : ""
}

module "compute" {
  count = local.tier != "economy" ? 1 : 0

  source = "../modules/azure/compute"

  name                   = local.name_prefix
  location               = azurerm_resource_group.main.location
  resource_group_name    = azurerm_resource_group.main.name
  instance_count         = local.vm_count
  vm_size                = local.vm_size
  os_image               = var.azure_vm_os
  admin_username         = var.azure_admin_username
  ssh_public_key         = var.azure_ssh_public_key != "" ? var.azure_ssh_public_key : tls_private_key.ssh.public_key_openssh
  subnet_id              = azurerm_subnet.main["main"].id
  enable_public_ip       = var.azure_public_ip_enabled
  availability_zones     = local.availability_zones
  os_disk_size_gb        = local.managed_disk_size
  os_disk_type           = local.managed_disk_type
  enable_data_disks      = local.tier != "economy"
  data_disk_size_gb      = local.managed_disk_size
  data_disk_type         = local.managed_disk_type
  managed_identity_id    = local.managed_identity_enabled ? module.identity[0].identity_id : ""
  cloud_init_configs     = module.kubernetes_bootstrap[0].cloud_init_configs
  use_static_private_ips = true
  subnet_cidr            = var.subnet_cidr
  tags                   = local.compute_tags
}

# ---------------------------------------------------------------------------
# Managed Identity (Standard/Enterprise)
# ---------------------------------------------------------------------------
module "identity" {
  count = local.managed_identity_enabled ? 1 : 0

  source = "../modules/azure/identity"

  name                    = local.name_prefix
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  enable_managed_identity = true
  key_vault_id            = local.key_vault_enabled ? module.secrets[0].key_vault_id : ""
  enable_key_vault_role   = local.key_vault_enabled
  storage_account_id      = local.storage_account_enabled ? module.storage[0].storage_account_id : ""
  enable_storage_role     = local.storage_account_enabled
  tags                    = local.common_tags
}

# ---------------------------------------------------------------------------
# Load Balancer (Standard/Enterprise)
# ---------------------------------------------------------------------------
module "load_balancer" {
  count = local.load_balancer_type != "none" ? 1 : 0

  source = "../modules/azure/load-balancer"

  name                = local.name_prefix
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  lb_type             = local.app_gateway_enabled ? "app-gateway" : local.load_balancer_type
  backend_nic_ids     = local.tier != "economy" ? module.compute[0].nic_ids : []
  availability_zones  = local.availability_zones
  tags                = local.common_tags
}

# ---------------------------------------------------------------------------
# Database (Standard/Enterprise)
# ---------------------------------------------------------------------------
module "database" {
  count = local.database_mode != "container" ? 1 : 0

  source = "../modules/azure/database"

  name                  = local.name_prefix
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  database_mode         = local.database_mode
  sku_name              = local.postgres_sku
  storage_mb            = local.postgres_storage_mb
  backup_retention_days = local.tier == "enterprise" ? 35 : 7
  vnet_id               = azurerm_virtual_network.main.id
  delegated_subnet_id   = local.enable_private_subnets ? azurerm_subnet.main["private"].id : ""
  enable_private_dns    = local.enable_private_subnets
  tags                  = local.common_tags
}

# ---------------------------------------------------------------------------
# Storage (Standard/Enterprise)
# ---------------------------------------------------------------------------
module "storage" {
  count = local.storage_account_enabled ? 1 : 0

  source = "../modules/azure/storage"

  name                      = local.name_prefix
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name
  enable_storage_account    = true
  storage_account_name      = local.storage_account_name
  replication_type          = local.storage_replication
  enable_versioning         = local.tier == "enterprise"
  enable_lifecycle_policy   = local.tier == "enterprise"
  enable_registry_container = true
  enable_logs_container     = local.tier == "enterprise"
  backup_retention_days     = local.tier == "enterprise" ? 365 : 30
  tags                      = local.common_tags
}

# ---------------------------------------------------------------------------
# Key Vault (Enterprise)
# ---------------------------------------------------------------------------
module "secrets" {
  count = local.key_vault_enabled ? 1 : 0

  source = "../modules/azure/secrets"

  name                       = local.name_prefix
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  enable_key_vault           = true
  key_vault_name             = local.key_vault_name
  sku_name                   = local.key_vault_sku != null ? local.key_vault_sku : "standard"
  allowed_subnet_ids         = [azurerm_subnet.main["main"].id]
  enable_ca_keys             = local.tier == "enterprise"
  enable_openbao_auto_unseal = local.tier == "enterprise"
  db_connection_string       = local.database_mode != "container" ? module.database[0].connection_string : ""
  tags                       = local.common_tags
}

# ---------------------------------------------------------------------------
# Monitoring (Standard/Enterprise)
# ---------------------------------------------------------------------------
module "monitoring" {
  count = local.log_analytics_enabled ? 1 : 0

  source = "../modules/azure/monitoring-bootstrap"

  name                   = local.name_prefix
  location               = azurerm_resource_group.main.location
  resource_group_name    = azurerm_resource_group.main.name
  enable_log_analytics   = local.log_analytics_enabled
  enable_app_insights    = local.app_insights_enabled
  retention_days         = local.tier == "enterprise" ? 365 : 30
  vm_ids                 = local.tier != "economy" ? module.compute[0].vm_ids : (local.tier == "economy" ? [azurerm_linux_virtual_machine.main[0].id] : [])
  nsg_id                 = azurerm_network_security_group.main.id
  enable_nsg_diagnostics = true
  alert_email            = var.alert_email
  tags                   = local.common_tags
}
