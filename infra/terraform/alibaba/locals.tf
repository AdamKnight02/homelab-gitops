# =============================================================================
# Alibaba Cloud Root Module — Local Values
# =============================================================================
# Local values for Alibaba Cloud resource naming, tagging, and derived config.
# =============================================================================

locals {
  # -------------------------------------------------------------------------
  # Naming Conventions
  # Format: {prefix}-{resource-type}-{suffix}
  # -------------------------------------------------------------------------
  name_prefix = var.name_prefix
  name_suffix = random_string.suffix.result

  vpc_name            = "${local.name_prefix}-vpc-${local.name_suffix}"
  vswitch_name        = "${local.name_prefix}-vsw-${local.name_suffix}"
  security_group_name = "${local.name_prefix}-sg-${local.name_suffix}"
  instance_name       = "${local.name_prefix}-ecs-${local.name_suffix}"
  key_pair_name       = "${local.name_prefix}-key-${local.name_suffix}"
  ram_role_name       = "${local.name_prefix}-role-${local.name_suffix}"

  # -------------------------------------------------------------------------
  # Common Tags
  # -------------------------------------------------------------------------
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.managed_by
    Owner       = var.owner
    Ephemeral   = var.ephemeral ? "true" : "false"
    CostCenter  = var.cost_center
  }

  # -------------------------------------------------------------------------
  # Tier-Aware Configuration
  # When service_tier is not economy, the root module delegates to the
  # modular composition in modules/alibaba/*.
  # -------------------------------------------------------------------------
  use_tier_modules = lower(var.service_tier) != "economy"

  # -------------------------------------------------------------------------
  # Cost Estimation (economy tier — inline resources)
  # ecs.t6-c1m2.large: ~$12/month, 30GB cloud_efficiency: ~$1.50/month
  # -------------------------------------------------------------------------
  estimated_monthly_cost_usd = var.alibaba_associate_public_ip ? 16.50 : 13.50
}

# ---------------------------------------------------------------------------
# Random Suffix for Unique Naming
# ---------------------------------------------------------------------------
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# ---------------------------------------------------------------------------
# SSH Key Pair (if not provided)
# ---------------------------------------------------------------------------
resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}
