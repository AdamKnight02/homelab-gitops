# =============================================================================
# Alibaba Cloud Tier Configuration
# =============================================================================
# Central tier-to-resource mapping. This file defines what each service tier
# means in terms of Alibaba Cloud infrastructure. All modules and the root
# module reference these locals to determine what to create.
#
# DESIGN PRINCIPLE: Tiers are intent declarations, not cloud SKUs.
# This file translates intent into Alibaba Cloud-specific resource decisions.
# =============================================================================

locals {
  # -------------------------------------------------------------------------
  # Tier Validation
  # -------------------------------------------------------------------------
  valid_tiers = ["economy", "standard", "enterprise"]
  tier        = lower(var.service_tier)

  # -------------------------------------------------------------------------
  # Tier-Driven Feature Flags
  # -------------------------------------------------------------------------
  # These flags control what gets created. Economy gets the minimum;
  # each higher tier adds capabilities.

  # Compute
  tier_instance_count = {
    economy    = 1
    standard   = 3
    enterprise = 6
  }

  tier_instance_type = {
    economy    = "ecs.t6-c1m2.large"
    standard   = "ecs.t6-c1m4.large"
    enterprise = "ecs.g6.xlarge"
  }

  # Networking
  tier_multi_zone = {
    economy    = false
    standard   = false
    enterprise = true
  }

  tier_nat_gateway = {
    economy    = false
    standard   = false
    enterprise = true
  }

  tier_eip_enabled = {
    economy    = false
    standard   = false
    enterprise = true
  }

  # Load Balancer
  tier_load_balancer = {
    economy    = "none" # No LB — NodePort only
    standard   = "nlb"  # Network Load Balancer
    enterprise = "nlb"  # NLB (SLB optional via var)
  }

  # Database
  tier_database = {
    economy    = "container"      # PostgreSQL in container on K3s node
    standard   = "rds"            # ApsaraDB RDS single-zone
    enterprise = "rds-multi-zone" # ApsaraDB RDS multi-zone HA
  }

  tier_rds_instance_type = {
    economy    = null
    standard   = "pg.n2.medium.2c"
    enterprise = "pg.n4.large.2c"
  }

  # Storage
  tier_oss_enabled = {
    economy    = false
    standard   = true
    enterprise = true
  }

  tier_oss_versioning = {
    economy    = false
    standard   = false
    enterprise = true
  }

  tier_disk_size = {
    economy    = 30
    standard   = 50
    enterprise = 100
  }

  tier_disk_category = {
    economy    = "cloud_efficiency"
    standard   = "cloud_ssd"
    enterprise = "cloud_essd"
  }

  # Secrets & KMS
  tier_kms_enabled = {
    economy    = false
    standard   = false
    enterprise = true
  }

  tier_secrets_manager = {
    economy    = false
    standard   = false
    enterprise = true
  }

  # Monitoring
  tier_detailed_monitoring = {
    economy    = false
    standard   = true
    enterprise = true
  }

  tier_cloudmonitor = {
    economy    = false
    standard   = true
    enterprise = true
  }

  # ACK (optional alternative to K3s for enterprise)
  tier_ack_enabled = {
    economy    = false
    standard   = false
    enterprise = false # ACK is opt-in via var.enable_ack
  }

  # -------------------------------------------------------------------------
  # Resolved Values (after tier lookup)
  # -------------------------------------------------------------------------
  instance_count          = local.tier_instance_count[local.tier]
  instance_type           = var.alibaba_instance_type_override != "" ? var.alibaba_instance_type_override : local.tier_instance_type[local.tier]
  multi_zone              = local.tier_multi_zone[local.tier]
  enable_nat_gateway      = local.tier_nat_gateway[local.tier]
  enable_eip              = local.tier_eip_enabled[local.tier]
  load_balancer_type      = local.tier_load_balancer[local.tier]
  database_mode           = local.tier_database[local.tier]
  rds_instance_type       = local.tier_rds_instance_type[local.tier]
  oss_enabled             = local.tier_oss_enabled[local.tier]
  oss_versioning          = local.tier_oss_versioning[local.tier]
  disk_size               = local.tier_disk_size[local.tier]
  disk_category           = local.tier_disk_category[local.tier]
  kms_enabled             = local.tier_kms_enabled[local.tier]
  secrets_manager_enabled = local.tier_secrets_manager[local.tier]
  detailed_monitoring     = local.tier_detailed_monitoring[local.tier]
  cloudmonitor_enabled    = local.tier_cloudmonitor[local.tier]

  # -------------------------------------------------------------------------
  # Zone Configuration by Tier
  # -------------------------------------------------------------------------
  # Economy:    1 zone
  # Standard:   1 zone (multi-node K3s, all in one zone for cost)
  # Enterprise: 3 zones

  zone_count = local.multi_zone ? 3 : 1

  # -------------------------------------------------------------------------
  # Cost Guardrail: Resource Counts
  # -------------------------------------------------------------------------
  cost_report = {
    ecs_instances   = local.instance_count
    disks           = local.instance_count # system disks
    disk_total_gb   = local.instance_count * local.disk_size
    nat_gateways    = local.enable_nat_gateway ? 1 : 0
    eip_addresses   = local.enable_eip ? 1 : 0
    public_ips      = var.alibaba_associate_public_ip ? local.instance_count : 0
    rds_instances   = local.database_mode != "container" ? 1 : 0
    rds_multi_zone  = local.database_mode == "rds-multi-zone" ? true : false
    ack_clusters    = var.enable_ack && local.tier == "enterprise" ? 1 : 0
    load_balancers  = local.load_balancer_type != "none" ? 1 : 0
    oss_buckets     = local.oss_enabled ? 1 : 0
    kms_keys        = local.kms_enabled ? 1 : 0
    secrets_manager = local.secrets_manager_enabled ? 1 : 0
  }

  # Estimated monthly cost (rough, for guardrail reporting)
  # Alibaba Cloud pricing is approximate and varies by region
  estimated_monthly_cost = (
    # ECS
    (local.tier == "economy" ? 12.0 : local.tier == "standard" ? 3 * 35.0 : 6 * 80.0) +
    # Disks
    (local.instance_count * local.disk_size * 0.05) +
    # NAT Gateway
    (local.enable_nat_gateway ? 30.0 : 0) +
    # EIP
    (local.enable_eip ? 3.0 : 0) +
    # Public IPs (bandwidth-based, rough estimate)
    (var.alibaba_associate_public_ip ? local.instance_count * 3.0 : 0) +
    # RDS
    (local.database_mode == "rds" ? 20.0 : local.database_mode == "rds-multi-zone" ? 80.0 : 0) +
    # NLB
    (local.load_balancer_type != "none" ? 15.0 : 0) +
    # OSS
    (local.oss_enabled ? 3.0 : 0) +
    # KMS
    (local.kms_enabled ? 1.0 : 0) +
    # Secrets Manager
    (local.secrets_manager_enabled ? 0.50 : 0)
  )
}
