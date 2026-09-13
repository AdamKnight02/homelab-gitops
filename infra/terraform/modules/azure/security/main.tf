# =============================================================================
# Azure Security Module — Main Resources
# =============================================================================
# Creates NSGs with tier-aware rules. Economy gets minimal rules;
# Standard/Enterprise get additional rules for K3s HA, LB health probes, etc.
# =============================================================================

# ---------------------------------------------------------------------------
# Network Security Group
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "main" {
  name                = "${var.name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

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

  # K3s API server — internal only (for multi-node)
  dynamic "security_rule" {
    for_each = var.enable_k3s_ha ? [1] : []
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
    for_each = var.enable_k3s_ha ? [1] : []
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
    for_each = var.enable_k3s_ha ? [1] : []
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
    for_each = var.enable_k3s_ha ? [1] : []
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
    for_each = var.enable_load_balancer ? [1] : []
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
    for_each = var.enable_ingress ? [1] : []
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
    for_each = var.enable_ingress ? [1] : []
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
    for_each = var.enable_nodeport ? [1] : []
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

  # Deny all other inbound (explicit for clarity)
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
  for_each = var.subnet_ids

  subnet_id                 = each.value
  network_security_group_id = azurerm_network_security_group.main.id
}
