# =============================================================================
# Azure Root Module — Local Values
# =============================================================================
# Local values for Azure resource naming, tagging, and derived configuration.
# Includes tier-driven configuration from the tier-config module.
# =============================================================================

# ---------------------------------------------------------------------------
# Tier Configuration (imported from shared module)
# ---------------------------------------------------------------------------
# The tier-config.tf in modules/azure/ defines all tier-to-resource mappings.
# We include it here via a module call so the root module can reference
# tier-driven locals directly.

module "tier_config" {
  source = "../modules/azure"

  # Pass through variables needed by tier-config
  service_tier            = var.service_tier
  azure_vm_size_override  = var.azure_vm_size_override
  azure_public_ip_enabled = var.azure_public_ip_enabled
  network_cidr            = var.network_cidr
  subnet_cidr             = var.subnet_cidr
  enable_aks              = var.enable_aks
  enable_app_gateway      = var.enable_app_gateway
}

locals {
  # -------------------------------------------------------------------------
  # Tier-Driven Values (resolved from tier-config module)
  # -------------------------------------------------------------------------
  tier                     = module.tier_config.tier
  vm_count                 = module.tier_config.vm_count
  vm_size                  = module.tier_config.vm_size
  availability_zones       = module.tier_config.availability_zones
  enable_nat_gateway       = module.tier_config.enable_nat_gateway
  enable_private_subnets   = module.tier_config.enable_private_subnets
  load_balancer_type       = module.tier_config.load_balancer_type
  app_gateway_enabled      = module.tier_config.app_gateway_enabled
  database_mode            = module.tier_config.database_mode
  postgres_sku             = module.tier_config.postgres_sku
  postgres_storage_mb      = module.tier_config.postgres_storage_mb
  storage_account_enabled  = module.tier_config.storage_account_enabled
  storage_replication      = module.tier_config.storage_replication
  managed_disk_size        = module.tier_config.managed_disk_size
  managed_disk_type        = module.tier_config.managed_disk_type
  key_vault_enabled        = module.tier_config.key_vault_enabled
  key_vault_sku            = module.tier_config.key_vault_sku
  managed_identity_enabled = module.tier_config.managed_identity_enabled
  log_analytics_enabled    = module.tier_config.log_analytics_enabled
  app_insights_enabled     = module.tier_config.app_insights_enabled
  subnets                  = module.tier_config.subnets
  cost_report              = module.tier_config.cost_report
  estimated_monthly_cost   = module.tier_config.estimated_monthly_cost
  economy_violations       = module.tier_config.economy_violations

  # -------------------------------------------------------------------------
  # Naming Conventions
  # Format: {prefix}-{resource-type}-{suffix}
  # -------------------------------------------------------------------------
  name_prefix = var.name_prefix
  name_suffix = random_string.suffix.result

  resource_group_name  = coalesce(var.resource_group_name, "${local.name_prefix}-rg-${local.name_suffix}")
  vnet_name            = coalesce(var.azure_vnet_name, "${local.name_prefix}-vnet-${local.name_suffix}")
  subnet_name          = coalesce(var.azure_subnet_name, "${local.name_prefix}-subnet-${local.name_suffix}")
  nsg_name             = coalesce(var.azure_nsg_name, "${local.name_prefix}-nsg-${local.name_suffix}")
  vm_name              = "${local.name_prefix}-vm-${local.name_suffix}"
  public_ip_name       = "${local.name_prefix}-pip-${local.name_suffix}"
  nic_name             = "${local.name_prefix}-nic-${local.name_suffix}"
  os_disk_name         = "${local.name_prefix}-osdisk-${local.name_suffix}"
  storage_account_name = "${replace(local.name_prefix, "-", "")}st${local.name_suffix}"
  key_vault_name       = "${local.name_prefix}-kv-${local.name_suffix}"

  # -------------------------------------------------------------------------
  # Common Tags (Azure-specific format)
  # -------------------------------------------------------------------------
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.managed_by
    Owner       = var.owner
    Ephemeral   = var.ephemeral ? "true" : "false"
    CostCenter  = var.cost_center
    Tier        = local.tier
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
    Purpose   = "vnet-subnet"
  })

  # -------------------------------------------------------------------------
  # Security Tags
  # -------------------------------------------------------------------------
  security_tags = merge(local.common_tags, {
    Component = "security"
    Purpose   = "nsg-firewall"
  })

  # -------------------------------------------------------------------------
  # K3s Bootstrap Configuration
  # Rendered as cloud-init user-data
  # -------------------------------------------------------------------------
  k3s_install_cmd = "curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=${var.k3s_version} sh -"

  # K3s token for multi-node clusters
  k3s_token_resolved = var.k3s_token != "" ? var.k3s_token : random_password.k3s_token.result

  cloud_init_config = templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
    admin_username      = var.azure_admin_username
    ssh_public_key      = var.azure_ssh_public_key != "" ? var.azure_ssh_public_key : tls_private_key.ssh.public_key_openssh
    k3s_version         = var.k3s_version
    argocd_version      = var.argocd_version
    git_repo_url        = var.git_repo_url
    git_target_revision = var.git_target_revision
    hostname            = local.vm_name
  })

  # -------------------------------------------------------------------------
  # Legacy Cost Estimation (kept for backward compatibility)
  # -------------------------------------------------------------------------
  estimated_monthly_cost_usd = local.estimated_monthly_cost
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

# ---------------------------------------------------------------------------
# K3s Cluster Token (for multi-node)
# ---------------------------------------------------------------------------
resource "random_password" "k3s_token" {
  length  = 32
  special = false
}
