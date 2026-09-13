# =============================================================================
# Alibaba Cloud Root Module — Main Resources
# =============================================================================
# This module defines the Alibaba Cloud infrastructure for the PKI platform.
#
# TIER-DRIVEN COMPOSITION:
#   economy    → Uses inline resources below (single ECS, minimal cost)
#   standard   → Delegates to modules/alibaba/* (3-node K3s, NLB, RDS, OSS)
#   enterprise → Delegates to modules/alibaba/* (6-node K3s, multi-zone, full HA)
#
# IMPORTANT: Alibaba Cloud is PLAN-ONLY — no credentials are configured.
# All validation is static (terraform validate / terraform plan will fail
# without credentials, but terraform validate passes).
# =============================================================================

# ---------------------------------------------------------------------------
# Data Sources (shared across all tiers)
# ---------------------------------------------------------------------------
data "alicloud_zones" "available" {
  available_resource_creation = "VSwitch"
}

# ---------------------------------------------------------------------------
# Image Data Source
# Latest Ubuntu 22.04 LTS
# ---------------------------------------------------------------------------
data "alicloud_images" "ubuntu" {
  most_recent = true
  owners      = "system"
  name_regex  = "^ubuntu_22_04_x64"
}

# =============================================================================
# ECONOMY TIER — Inline Resources (single ECS, minimal cost)
# =============================================================================
# These resources are created ONLY when service_tier = "economy" (default).
# For standard/enterprise, the module composition below is used instead.
# =============================================================================

# ---------------------------------------------------------------------------
# VPC (economy only)
# ---------------------------------------------------------------------------
resource "alicloud_vpc" "main" {
  count = local.use_tier_modules ? 0 : 1

  vpc_name   = local.vpc_name
  cidr_block = var.alibaba_vpc_cidr
  tags       = local.common_tags
}

# ---------------------------------------------------------------------------
# VSwitch (economy only)
# ---------------------------------------------------------------------------
resource "alicloud_vswitch" "main" {
  count = local.use_tier_modules ? 0 : 1

  vswitch_name = local.vswitch_name
  vpc_id       = alicloud_vpc.main[0].id
  cidr_block   = var.alibaba_subnet_cidr
  zone_id      = var.alibaba_zone_id != "" ? var.alibaba_zone_id : data.alicloud_zones.available.zones[0].id
  tags         = local.common_tags
}

# ---------------------------------------------------------------------------
# Security Group (economy only)
# Default: deny all inbound. SSH only if allow_ssh_cidr is specified.
# ---------------------------------------------------------------------------
resource "alicloud_security_group" "main" {
  count = local.use_tier_modules ? 0 : 1

  security_group_name = local.security_group_name
  description         = "Security group for PKI platform ECS instance"
  vpc_id              = alicloud_vpc.main[0].id
  tags                = local.common_tags
}

resource "alicloud_security_group_rule" "ssh" {
  for_each = local.use_tier_modules ? toset([]) : toset(var.allow_ssh_cidr)

  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "22/22"
  priority          = 1
  security_group_id = alicloud_security_group.main[0].id
  cidr_ip           = each.value
  description       = "SSH from ${each.value}"
}

resource "alicloud_security_group_rule" "egress" {
  count = local.use_tier_modules ? 0 : 1

  type              = "egress"
  ip_protocol       = "all"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "-1/-1"
  priority          = 1
  security_group_id = alicloud_security_group.main[0].id
  cidr_ip           = "0.0.0.0/0"
  description       = "Allow all outbound traffic"
}

# ---------------------------------------------------------------------------
# SSH Key Pair (all tiers — shared)
# ---------------------------------------------------------------------------
resource "alicloud_ecs_key_pair" "main" {
  key_pair_name = local.key_pair_name
  public_key    = var.alibaba_ssh_public_key != "" ? var.alibaba_ssh_public_key : tls_private_key.ssh.public_key_openssh
  tags          = local.common_tags
}

# ---------------------------------------------------------------------------
# RAM Role (economy only)
# ---------------------------------------------------------------------------
resource "alicloud_ram_role" "main" {
  count = !local.use_tier_modules && var.alibaba_create_ram_role ? 1 : 0

  role_name = local.ram_role_name
  assume_role_policy_document = jsonencode({
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = ["ecs.aliyuncs.com"]
      }
    }]
    Version = "1"
  })
  description = "RAM role for PKI platform ECS instance"
  force       = true
  tags        = local.common_tags
}

# ---------------------------------------------------------------------------
# ECS Instance (economy only)
# ---------------------------------------------------------------------------
resource "alicloud_instance" "main" {
  count = local.use_tier_modules ? 0 : 1

  instance_name   = local.instance_name
  instance_type   = "ecs.t6-c1m2.large"
  image_id        = data.alicloud_images.ubuntu.images[0].id
  vswitch_id      = alicloud_vswitch.main[0].id
  security_groups = [alicloud_security_group.main[0].id]
  role_name       = var.alibaba_create_ram_role ? alicloud_ram_role.main[0].role_name : null
  key_name        = alicloud_ecs_key_pair.main.key_pair_name

  system_disk_category = var.alibaba_root_volume_category
  system_disk_size     = var.alibaba_root_volume_size

  internet_max_bandwidth_out = var.alibaba_associate_public_ip ? var.alibaba_internet_max_bandwidth_out : 0

  user_data = base64encode(local.cloud_init_config)

  tags = merge(local.common_tags, {
    Name = local.instance_name
  })

  lifecycle {
    ignore_changes = [
      user_data,
      image_id,
    ]
  }
}

# ---------------------------------------------------------------------------
# Cloud-Init Configuration (economy only)
# ---------------------------------------------------------------------------
locals {
  cloud_init_config = templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
    admin_username      = var.alibaba_admin_username
    ssh_public_key      = var.alibaba_ssh_public_key != "" ? var.alibaba_ssh_public_key : tls_private_key.ssh.public_key_openssh
    k3s_version         = var.k3s_version
    argocd_version      = var.argocd_version
    git_repo_url        = var.git_repo_url
    git_target_revision = var.git_target_revision
    hostname            = local.instance_name
    server_url          = ""
    token               = ""
    is_server           = true
    disable_traefik     = true
    disable_servicelb   = true
  })
}

# =============================================================================
# STANDARD / ENTERPRISE TIER — Module Composition
# =============================================================================
# When service_tier is "standard" or "enterprise", the root module delegates
# to the modular composition in modules/alibaba/*. Each module is tier-aware
# and reads from the central tier-config.
# =============================================================================

# ---------------------------------------------------------------------------
# Tier Configuration (shared locals for all modules)
# ---------------------------------------------------------------------------
module "tier_config" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/alibaba/tier-config"

  service_tier                   = var.service_tier
  alibaba_instance_type_override = var.alibaba_instance_type_override
  alibaba_associate_public_ip    = var.alibaba_associate_public_ip
  enable_ack                     = var.enable_ack
}

# ---------------------------------------------------------------------------
# Network Module (standard/enterprise)
# ---------------------------------------------------------------------------
module "network" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/alibaba/network"

  name               = "${local.name_prefix}-${local.name_suffix}"
  cidr_block         = var.alibaba_vpc_cidr
  subnets            = { main = var.alibaba_subnet_cidr }
  enable_nat_gateway = module.tier_config[0].enable_nat_gateway
  enable_eip         = module.tier_config[0].enable_eip
  tags               = local.common_tags
}

# ---------------------------------------------------------------------------
# Security Module (standard/enterprise)
# ---------------------------------------------------------------------------
module "security" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/alibaba/security"

  name               = "${local.name_prefix}-${local.name_suffix}"
  vpc_id             = module.network[0].vpc_id
  allow_ssh_cidr     = var.allow_ssh_cidr
  allow_k8s_api_cidr = ["10.0.0.0/8"]
  allow_http_cidr    = []
  allow_https_cidr   = []
  tags               = local.common_tags
}

# ---------------------------------------------------------------------------
# Identity Module (standard/enterprise)
# ---------------------------------------------------------------------------
module "identity" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/alibaba/identity"

  name            = "${local.name_prefix}-${local.name_suffix}"
  create_ram_role = var.alibaba_create_ram_role
  tags            = local.common_tags
}

# ---------------------------------------------------------------------------
# Secrets Module (standard/enterprise) — KMS + Secrets Manager
# ---------------------------------------------------------------------------
module "secrets" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/alibaba/secrets"

  name           = "${local.name_prefix}-${local.name_suffix}"
  create_kms_key = module.tier_config[0].kms_enabled
  create_secret  = module.tier_config[0].secrets_manager_enabled
  tags           = local.common_tags
}

# ---------------------------------------------------------------------------
# Storage Module (standard/enterprise) — OSS
# ---------------------------------------------------------------------------
module "storage" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/alibaba/storage"

  name              = "${local.name_prefix}-${local.name_suffix}"
  create_oss_bucket = module.tier_config[0].oss_enabled
  oss_versioning    = module.tier_config[0].oss_versioning
  tags              = local.common_tags
}

# ---------------------------------------------------------------------------
# Database Module (standard/enterprise) — ApsaraDB RDS PostgreSQL
# ---------------------------------------------------------------------------
module "database" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/alibaba/database"

  name               = "${local.name_prefix}-${local.name_suffix}"
  create_rds         = module.tier_config[0].database_mode != "container"
  instance_type      = module.tier_config[0].rds_instance_type != null ? module.tier_config[0].rds_instance_type : "pg.n2.medium.2c"
  vswitch_id         = module.network[0].vswitch_ids["main"]
  security_group_ids = [module.security[0].security_group_id]
  ha_enabled         = module.tier_config[0].database_mode == "rds-multi-zone"
  tags               = local.common_tags
}

# ---------------------------------------------------------------------------
# Kubernetes Bootstrap Module (standard/enterprise)
# ---------------------------------------------------------------------------
module "kubernetes_bootstrap" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/alibaba/kubernetes-bootstrap"

  name                = "${local.name_prefix}-${local.name_suffix}"
  admin_username      = var.alibaba_admin_username
  ssh_public_key      = var.alibaba_ssh_public_key != "" ? var.alibaba_ssh_public_key : tls_private_key.ssh.public_key_openssh
  k3s_version         = var.k3s_version
  argocd_version      = var.argocd_version
  git_repo_url        = var.git_repo_url
  git_target_revision = var.git_target_revision
  hostname            = "${local.name_prefix}-k3s-${local.name_suffix}"
  is_server           = true
  disable_traefik     = true
  disable_servicelb   = true
  tags                = local.common_tags
}

# ---------------------------------------------------------------------------
# Compute Module (standard/enterprise) — ECS instances for K3s
# ---------------------------------------------------------------------------
module "compute" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/alibaba/compute"

  name                       = "${local.name_prefix}-${local.name_suffix}"
  instance_count             = module.tier_config[0].instance_count
  instance_type              = module.tier_config[0].instance_type
  vswitch_id                 = module.network[0].vswitch_ids["main"]
  security_group_ids         = [module.security[0].security_group_id]
  ram_role_name              = var.alibaba_create_ram_role ? module.identity[0].ram_role_name : null
  key_name                   = alicloud_ecs_key_pair.main.key_pair_name
  system_disk_category       = module.tier_config[0].disk_category
  system_disk_size           = module.tier_config[0].disk_size
  internet_max_bandwidth_out = var.alibaba_associate_public_ip ? var.alibaba_internet_max_bandwidth_out : 0
  user_data                  = module.kubernetes_bootstrap[0].cloud_init_config
  tags                       = local.common_tags
}

# ---------------------------------------------------------------------------
# Load Balancer Module (standard/enterprise)
# ---------------------------------------------------------------------------
module "load_balancer" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/alibaba/load-balancer"

  name            = "${local.name_prefix}-${local.name_suffix}"
  create_slb      = module.tier_config[0].load_balancer_type != "none"
  slb_type        = module.tier_config[0].load_balancer_type == "nlb" ? "nlb" : "slb"
  vswitch_id      = module.network[0].vswitch_ids["main"]
  vpc_id          = module.network[0].vpc_id
  backend_servers = module.compute[0].instance_ids
  tags            = local.common_tags
}

# ---------------------------------------------------------------------------
# Monitoring Bootstrap Module (standard/enterprise)
# ---------------------------------------------------------------------------
module "monitoring" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/alibaba/monitoring-bootstrap"

  name                = "${local.name_prefix}-${local.name_suffix}"
  enable_cloudmonitor = module.tier_config[0].cloudmonitor_enabled
  enable_prometheus   = module.tier_config[0].detailed_monitoring
  enable_grafana      = module.tier_config[0].detailed_monitoring
  tags                = local.common_tags
}
