# =============================================================================
# Alibaba Cloud Load Balancer Module — Main Resources
# =============================================================================

# ---------------------------------------------------------------------------
# Server Load Balancer (SLB)
# ---------------------------------------------------------------------------
resource "alicloud_slb_load_balancer" "main" {
  count = var.create_slb && var.slb_type == "slb" ? 1 : 0

  load_balancer_name = "${var.name}-slb"
  load_balancer_spec = var.slb_spec
  address_type       = var.address_type
  vswitch_id         = var.vswitch_id
  master_zone_id     = var.master_zone_id != "" ? var.master_zone_id : null
  slave_zone_id      = var.slave_zone_id != "" ? var.slave_zone_id : null

  tags = var.tags
}

# ---------------------------------------------------------------------------
# SLB Listeners
# ---------------------------------------------------------------------------
resource "alicloud_slb_listener" "main" {
  for_each = var.create_slb && var.slb_type == "slb" ? var.listener_ports : {}

  load_balancer_id = alicloud_slb_load_balancer.main[0].id
  frontend_port    = each.value.frontend_port
  backend_port     = each.value.backend_port
  protocol         = each.value.protocol
  bandwidth        = -1

  health_check              = var.health_check.enabled ? "on" : "off"
  health_check_type         = var.health_check.check_type
  health_check_connect_port = var.health_check.check_port
  health_check_interval     = var.health_check.check_interval
  health_check_timeout      = var.health_check.check_timeout
  healthy_threshold         = var.health_check.healthy_threshold
  unhealthy_threshold       = var.health_check.unhealthy_threshold
}

# ---------------------------------------------------------------------------
# SLB Backend Servers
# ---------------------------------------------------------------------------
resource "alicloud_slb_backend_server" "main" {
  count = var.create_slb && var.slb_type == "slb" ? 1 : 0

  load_balancer_id = alicloud_slb_load_balancer.main[0].id

  dynamic "backend_servers" {
    for_each = var.backend_servers
    content {
      server_id = backend_servers.value
      weight    = 100
    }
  }
}

# ---------------------------------------------------------------------------
# Network Load Balancer (NLB) — for higher performance
# ---------------------------------------------------------------------------
resource "alicloud_nlb_load_balancer" "main" {
  count = var.create_slb && var.slb_type == "nlb" ? 1 : 0

  load_balancer_name = "${var.name}-nlb"
  address_type       = var.address_type
  vpc_id             = var.vpc_id
  zone_mappings {
    vswitch_id = var.vswitch_id
    zone_id    = var.master_zone_id != "" ? var.master_zone_id : "cn-hangzhou-a"
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# NLB Server Group
# ---------------------------------------------------------------------------
resource "alicloud_nlb_server_group" "main" {
  count = var.create_slb && var.slb_type == "nlb" ? 1 : 0

  server_group_name = "${var.name}-sg"
  vpc_id            = var.vpc_id
  protocol          = "TCP"
  scheduler         = "Wrr"

  health_check {
    health_check_enabled  = var.health_check.enabled
    health_check_type     = var.health_check.check_type
    health_check_interval = var.health_check.check_interval
    healthy_threshold     = var.health_check.healthy_threshold
    unhealthy_threshold   = var.health_check.unhealthy_threshold
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# NLB Listeners
# ---------------------------------------------------------------------------
resource "alicloud_nlb_listener" "main" {
  for_each = var.create_slb && var.slb_type == "nlb" ? var.listener_ports : {}

  load_balancer_id  = alicloud_nlb_load_balancer.main[0].id
  listener_port     = each.value.frontend_port
  listener_protocol = each.value.protocol
  server_group_id   = alicloud_nlb_server_group.main[0].id
}
