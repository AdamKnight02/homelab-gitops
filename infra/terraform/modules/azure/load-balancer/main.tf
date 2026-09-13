# =============================================================================
# Azure Load Balancer Module — Main Resources
# =============================================================================
# Creates Azure Load Balancer (Basic/Standard) or Application Gateway.
# Standard tier: Basic LB (free). Enterprise: Standard LB or App Gateway.
# =============================================================================

# ---------------------------------------------------------------------------
# Public IP for Load Balancer
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "lb" {
  count = var.lb_type != "none" ? 1 : 0

  name                = "${var.name}-lb-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard" # Basic SKU deprecated March 2025
  zones               = var.lb_type == "standard" && var.availability_zones > 0 ? ["1", "2", "3"] : null
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Azure Load Balancer (Basic or Standard)
# ---------------------------------------------------------------------------
resource "azurerm_lb" "main" {
  count = var.lb_type != "none" && var.lb_type != "app-gateway" ? 1 : 0

  name                = "${var.name}-lb"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.lb_type == "standard" ? "Standard" : "Basic"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.lb[0].id
  }
}

# ---------------------------------------------------------------------------
# Backend Address Pool
# ---------------------------------------------------------------------------
resource "azurerm_lb_backend_address_pool" "main" {
  count = var.lb_type != "none" && var.lb_type != "app-gateway" ? 1 : 0

  name            = "backend"
  loadbalancer_id = azurerm_lb.main[0].id
}

# ---------------------------------------------------------------------------
# Health Probe — K3s API
# ---------------------------------------------------------------------------
resource "azurerm_lb_probe" "k3s_api" {
  count = var.lb_type != "none" && var.lb_type != "app-gateway" ? 1 : 0

  name            = "k3s-api-probe"
  loadbalancer_id = azurerm_lb.main[0].id
  protocol        = "Tcp"
  port            = 6443
}

# ---------------------------------------------------------------------------
# Health Probe — HTTP Ingress
# ---------------------------------------------------------------------------
resource "azurerm_lb_probe" "http" {
  count = var.lb_type == "standard" ? 1 : 0

  name            = "http-probe"
  loadbalancer_id = azurerm_lb.main[0].id
  protocol        = "Http"
  port            = 80
  request_path    = "/healthz"
}

# ---------------------------------------------------------------------------
# LB Rule — K3s API (for multi-node control plane)
# ---------------------------------------------------------------------------
resource "azurerm_lb_rule" "k3s_api" {
  count = var.lb_type != "none" && var.lb_type != "app-gateway" ? 1 : 0

  name                           = "k3s-api"
  loadbalancer_id                = azurerm_lb.main[0].id
  protocol                       = "Tcp"
  frontend_port                  = 6443
  backend_port                   = 6443
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main[0].id]
  probe_id                       = azurerm_lb_probe.k3s_api[0].id
}

# ---------------------------------------------------------------------------
# LB Rule — HTTP
# ---------------------------------------------------------------------------
resource "azurerm_lb_rule" "http" {
  count = var.lb_type == "standard" ? 1 : 0

  name                           = "http"
  loadbalancer_id                = azurerm_lb.main[0].id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main[0].id]
  probe_id                       = azurerm_lb_probe.http[0].id
}

# ---------------------------------------------------------------------------
# LB Rule — HTTPS
# ---------------------------------------------------------------------------
resource "azurerm_lb_rule" "https" {
  count = var.lb_type == "standard" ? 1 : 0

  name                           = "https"
  loadbalancer_id                = azurerm_lb.main[0].id
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main[0].id]
  probe_id                       = azurerm_lb_probe.http[0].id
}

# ---------------------------------------------------------------------------
# Backend Pool Associations (NICs)
# ---------------------------------------------------------------------------
resource "azurerm_network_interface_backend_address_pool_association" "main" {
  count = var.lb_type != "none" && var.lb_type != "app-gateway" ? length(var.backend_nic_ids) : 0

  network_interface_id    = var.backend_nic_ids[count.index]
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main[0].id
}

# ---------------------------------------------------------------------------
# Application Gateway (Enterprise, opt-in)
# ---------------------------------------------------------------------------
resource "azurerm_application_gateway" "main" {
  count = var.lb_type == "app-gateway" ? 1 : 0

  name                = "${var.name}-appgw"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = var.app_gateway_capacity
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = var.app_gateway_subnet_id
  }

  frontend_port {
    name = "http"
    port = 80
  }

  frontend_port {
    name = "https"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.lb[0].id
  }

  backend_address_pool {
    name = "backend"
  }

  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "http-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "backend"
    backend_http_settings_name = "http-settings"
    priority                   = 100
  }
}
