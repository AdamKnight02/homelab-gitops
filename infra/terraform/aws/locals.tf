# =============================================================================
# AWS Root Module — Local Values
# =============================================================================
# Local values for AWS resource naming, tagging, and derived configuration.
# =============================================================================

locals {
  # -------------------------------------------------------------------------
  # Naming Conventions
  # Format: {prefix}-{resource-type}-{suffix}
  # Using underscores for AWS compatibility where needed
  # -------------------------------------------------------------------------
  name_prefix = var.name_prefix
  name_suffix = random_string.suffix.result

  vpc_name            = "${local.name_prefix}-vpc-${local.name_suffix}"
  subnet_name         = "${local.name_prefix}-subnet-${local.name_suffix}"
  igw_name            = "${local.name_prefix}-igw-${local.name_suffix}"
  route_table_name    = "${local.name_prefix}-rt-${local.name_suffix}"
  security_group_name = "${local.name_prefix}-sg-${local.name_suffix}"
  instance_name       = "${local.name_prefix}-ec2-${local.name_suffix}"
  key_pair_name       = "${local.name_prefix}-key-${local.name_suffix}"
  iam_role_name       = coalesce(var.aws_iam_role_name, "${local.name_prefix}-role-${local.name_suffix}")
  iam_profile_name    = "${local.name_prefix}-profile-${local.name_suffix}"

  # -------------------------------------------------------------------------
  # Common Tags (AWS-specific — also applied via provider default_tags)
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
  # Compute Tags
  # -------------------------------------------------------------------------
  compute_tags = merge(local.common_tags, {
    Component = "compute"
    Purpose   = "k3s-node"
  })

  # -------------------------------------------------------------------------
  # Network Tags
  # -------------------------------------------------------------------------
  network_tags = merge(local.common_tags, {
    Component = "network"
    Purpose   = "vpc-subnet"
  })

  # -------------------------------------------------------------------------
  # Security Tags
  # -------------------------------------------------------------------------
  security_tags = merge(local.common_tags, {
    Component = "security"
    Purpose   = "security-group"
  })

  # -------------------------------------------------------------------------
  # K3s Bootstrap Configuration
  # Rendered as cloud-init user-data
  # -------------------------------------------------------------------------
  k3s_install_cmd = "curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=${var.k3s_version} sh -"

  cloud_init_config = templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
    admin_username      = var.aws_admin_username
    ssh_public_key      = var.aws_ssh_public_key != "" ? var.aws_ssh_public_key : tls_private_key.ssh.public_key_openssh
    k3s_version         = var.k3s_version
    argocd_version      = var.argocd_version
    git_repo_url        = var.git_repo_url
    git_target_revision = var.git_target_revision
    hostname            = local.instance_name
  })

  # -------------------------------------------------------------------------
  # Cost Estimation (for documentation — not used in resources)
  # Economy: t3.micro on-demand: ~$8.50/month, gp3 20GB: ~$1.60/month
  # Public IPv4 (if enabled): ~$3.60/month (new AWS charge as of Feb 2024)
  # For standard/enterprise, see module-tier-cost-report output
  # -------------------------------------------------------------------------
  estimated_monthly_cost_usd = var.aws_associate_public_ip ? 13.70 : 10.10

  # -------------------------------------------------------------------------
  # Tier-Aware Configuration (standard/enterprise only)
  # When service_tier is not economy, the root module delegates to the
  # modular composition in modules/aws/*.
  # -------------------------------------------------------------------------
  use_tier_modules = lower(var.service_tier) != "economy"
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
