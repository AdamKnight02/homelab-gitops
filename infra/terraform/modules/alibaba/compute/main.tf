# =============================================================================
# Alibaba Cloud Compute Module — Main Resources
# =============================================================================

# ---------------------------------------------------------------------------
# Locals — deterministic key management
# ---------------------------------------------------------------------------
# Determine whether we need to create a key pair or use an existing one.
# These locals use ONLY input variables (known at plan time), never resource
# attributes, so count expressions are always deterministic.
locals {
  create_key_pair = var.key_name == "" ? true : false
  # The key name to use on instances: either the provided name or the generated one
  effective_key_name = var.key_name != "" ? var.key_name : "${var.name}-key"
}

# ---------------------------------------------------------------------------
# Data Sources
# ---------------------------------------------------------------------------
data "alicloud_images" "ubuntu" {
  count = var.image_id == "" ? 1 : 0

  most_recent = true
  owners      = "system"
  name_regex  = "^ubuntu_22_04_x64"
}

# ---------------------------------------------------------------------------
# SSH Key Pair
# ---------------------------------------------------------------------------
resource "tls_private_key" "ssh" {
  count = local.create_key_pair && var.ssh_public_key == "" ? 1 : 0

  algorithm = "ED25519"
}

resource "alicloud_ecs_key_pair" "main" {
  count = local.create_key_pair ? 1 : 0

  key_pair_name = local.effective_key_name
  public_key    = var.ssh_public_key != "" ? var.ssh_public_key : tls_private_key.ssh[0].public_key_openssh
  tags          = var.tags
}

# ---------------------------------------------------------------------------
# ECS Instances
# ---------------------------------------------------------------------------
resource "alicloud_instance" "main" {
  count = var.instance_count

  instance_name   = "${var.name}-ecs-${count.index + 1}"
  instance_type   = var.instance_type
  image_id        = var.image_id != "" ? var.image_id : data.alicloud_images.ubuntu[0].images[0].id
  vswitch_id      = var.vswitch_id
  security_groups = var.security_group_ids
  role_name       = var.ram_role_name

  key_name = local.effective_key_name

  system_disk_category = var.system_disk_category
  system_disk_size     = var.system_disk_size

  internet_max_bandwidth_out = var.internet_max_bandwidth_out

  user_data = var.user_data != "" ? base64encode(var.user_data) : null

  tags = merge(var.tags, {
    Name = "${var.name}-ecs-${count.index + 1}"
  })

  lifecycle {
    ignore_changes = [
      user_data,
      image_id,
    ]
  }

  depends_on = [alicloud_ecs_key_pair.main]
}

# ---------------------------------------------------------------------------
# Data Disks
# ---------------------------------------------------------------------------
data "alicloud_zones" "available" {
  available_resource_creation = "VSwitch"
}

resource "alicloud_disk" "main" {
  for_each = { for idx, disk in var.data_disks : idx => disk }

  disk_name = "${var.name}-${each.value.name}"
  category  = each.value.category
  size      = each.value.size
  zone_id   = data.alicloud_zones.available.zones[0].id
  tags      = var.tags
}

resource "alicloud_disk_attachment" "main" {
  for_each = { for idx, disk in var.data_disks : idx => disk }

  disk_id     = alicloud_disk.main[each.key].id
  instance_id = alicloud_instance.main[0].id
}
