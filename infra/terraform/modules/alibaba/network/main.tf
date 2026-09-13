# =============================================================================
# Alibaba Cloud Network Module — Main Resources
# =============================================================================

# ---------------------------------------------------------------------------
# Data Sources
# ---------------------------------------------------------------------------
data "alicloud_zones" "available" {
  available_resource_creation = "VSwitch"
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------
resource "alicloud_vpc" "main" {
  vpc_name   = "${var.name}-vpc"
  cidr_block = var.cidr_block
  tags       = var.tags
}

# ---------------------------------------------------------------------------
# VSwitch (Subnet)
# ---------------------------------------------------------------------------
resource "alicloud_vswitch" "main" {
  for_each = var.subnets

  vswitch_name = "${var.name}-${each.key}"
  vpc_id       = alicloud_vpc.main.id
  cidr_block   = each.value
  zone_id      = length(var.zone_ids) > 0 ? var.zone_ids[0] : data.alicloud_zones.available.zones[0].id
  tags         = var.tags
}

# ---------------------------------------------------------------------------
# Route Table (default route table is created automatically with VPC)
# ---------------------------------------------------------------------------
# Alibaba Cloud creates a default route table with the VPC.
# Custom route tables can be added here if needed.

# ---------------------------------------------------------------------------
# NAT Gateway (optional — cost warning)
# ---------------------------------------------------------------------------
resource "alicloud_nat_gateway" "main" {
  count = var.enable_nat_gateway ? 1 : 0

  vpc_id           = alicloud_vpc.main.id
  nat_gateway_name = "${var.name}-nat"
  payment_type     = "PayAsYouGo"
  vswitch_id       = alicloud_vswitch.main[keys(var.subnets)[0]].id
  nat_type         = "Enhanced"

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Elastic IP (optional — for NAT gateway or direct attachment)
# ---------------------------------------------------------------------------
resource "alicloud_eip_address" "main" {
  count = var.enable_eip ? 1 : 0

  address_name         = "${var.name}-eip"
  bandwidth            = 5
  internet_charge_type = "PayByTraffic"
  payment_type         = "PayAsYouGo"

  tags = var.tags
}

# ---------------------------------------------------------------------------
# EIP Association to NAT Gateway
# ---------------------------------------------------------------------------
resource "alicloud_eip_association" "nat" {
  count = var.enable_nat_gateway && var.enable_eip ? 1 : 0

  allocation_id = alicloud_eip_address.main[0].id
  instance_id   = alicloud_nat_gateway.main[0].id
  instance_type = "Nat"
}

# ---------------------------------------------------------------------------
# SNAT Entry (if NAT gateway enabled)
# ---------------------------------------------------------------------------
resource "alicloud_snat_entry" "main" {
  count = var.enable_nat_gateway && var.enable_eip ? 1 : 0

  snat_table_id     = alicloud_nat_gateway.main[0].snat_table_ids
  source_vswitch_id = alicloud_vswitch.main[keys(var.subnets)[0]].id
  snat_ip           = alicloud_eip_address.main[0].ip_address
}
