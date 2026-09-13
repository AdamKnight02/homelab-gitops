# =============================================================================
# Azure Tier Configuration
# =============================================================================
# Central tier-to-resource mapping. This file defines what each service tier
# means in terms of Azure infrastructure. All modules and the root module
# reference these locals to determine what to create.
#
# DESIGN PRINCIPLE: Tiers are intent declarations, not cloud SKUs.
# This file translates intent into Azure-specific resource decisions.
#
# PATTERN: Follows the AWS tier-config.tf pattern exactly.
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
  tier_vm_count = {
    economy    = 1
    standard   = 3
    enterprise = 6
  }

  tier_vm_size = {
    economy    = "Standard_B2s"
    standard   = "Standard_B2ms"
    enterprise = "Standard_D4s_v3"
  }

  tier_availability_zones = {
    economy    = 0 # No zones (single node)
    standard   = 0 # No zones (cost control, single region)
    enterprise = 3 # Multi-zone
  }

  # Networking
  tier_nat_gateway = {
    economy    = false
    standard   = false
    enterprise = false # Azure NAT Gateway is expensive; opt-in only
  }

  tier_private_subnets = {
    economy    = false
    standard   = false
    enterprise = true
  }

  # Load Balancer
  tier_load_balancer = {
    economy    = "none"     # No LB — NodePort only
    standard   = "standard" # Azure Standard LB (Basic SKU deprecated March 2025)
    enterprise = "standard" # Azure Standard LB or App Gateway
  }

  tier_app_gateway = {
    economy    = false
    standard   = false
    enterprise = false # App Gateway is opt-in via var.enable_app_gateway
  }

  # Database
  tier_database = {
    economy    = "container"         # PostgreSQL in container on K3s node
    standard   = "azure-flexible"    # Azure Database for PostgreSQL Flexible (Burstable)
    enterprise = "azure-flexible-ha" # Azure Database for PostgreSQL Flexible (HA)
  }

  tier_postgres_sku = {
    economy    = null
    standard   = "B_Standard_B1ms"    # Burstable, ~$12/month
    enterprise = "GP_Standard_D2s_v3" # General Purpose, ~$100/month
  }

  tier_postgres_storage_mb = {
    economy    = null
    standard   = 32768  # 32 GB
    enterprise = 131072 # 128 GB
  }

  # Storage
  tier_storage_account = {
    economy    = false
    standard   = true
    enterprise = true
  }

  tier_storage_replication = {
    economy    = "LRS"
    standard   = "LRS"
    enterprise = "ZRS"
  }

  tier_managed_disk_size = {
    economy    = 30
    standard   = 50
    enterprise = 100
  }

  tier_managed_disk_type = {
    economy    = "StandardSSD_LRS"
    standard   = "Premium_LRS"
    enterprise = "Premium_ZRS"
  }

  # Secrets & Key Vault
  tier_key_vault = {
    economy    = false
    standard   = false
    enterprise = true
  }

  tier_key_vault_sku = {
    economy    = null
    standard   = null
    enterprise = "standard" # Use "premium" for HSM-backed keys
  }

  # Managed Identity
  tier_managed_identity = {
    economy    = false
    standard   = true
    enterprise = true
  }

  # Monitoring
  tier_log_analytics = {
    economy    = false
    standard   = true
    enterprise = true
  }

  tier_app_insights = {
    economy    = false
    standard   = false
    enterprise = true
  }

  # AKS (optional alternative to K3s for enterprise)
  tier_aks_enabled = {
    economy    = false
    standard   = false
    enterprise = false # AKS is opt-in via var.enable_aks
  }

  # -------------------------------------------------------------------------
  # Resolved Values (after tier lookup)
  # -------------------------------------------------------------------------
  vm_count                 = local.tier_vm_count[local.tier]
  vm_size                  = var.azure_vm_size_override != "" ? var.azure_vm_size_override : local.tier_vm_size[local.tier]
  availability_zones       = local.tier_availability_zones[local.tier]
  enable_nat_gateway       = local.tier_nat_gateway[local.tier]
  enable_private_subnets   = local.tier_private_subnets[local.tier]
  load_balancer_type       = local.tier_load_balancer[local.tier]
  app_gateway_enabled      = local.tier_app_gateway[local.tier]
  database_mode            = local.tier_database[local.tier]
  postgres_sku             = local.tier_postgres_sku[local.tier]
  postgres_storage_mb      = local.tier_postgres_storage_mb[local.tier]
  storage_account_enabled  = local.tier_storage_account[local.tier]
  storage_replication      = local.tier_storage_replication[local.tier]
  managed_disk_size        = local.tier_managed_disk_size[local.tier]
  managed_disk_type        = local.tier_managed_disk_type[local.tier]
  key_vault_enabled        = local.tier_key_vault[local.tier]
  key_vault_sku            = local.tier_key_vault_sku[local.tier]
  managed_identity_enabled = local.tier_managed_identity[local.tier]
  log_analytics_enabled    = local.tier_log_analytics[local.tier]
  app_insights_enabled     = local.tier_app_insights[local.tier]

  # -------------------------------------------------------------------------
  # Subnet Configuration by Tier
  # -------------------------------------------------------------------------
  # Economy:    1 subnet (all-in-one)
  # Standard:   1 subnet (multi-node K3s, all in one region for cost)
  # Enterprise: 2 subnets (public + private) across availability zones

  subnet_config = {
    economy = {
      main = var.subnet_cidr
    }
    standard = {
      main = var.subnet_cidr
    }
    enterprise = {
      main    = var.subnet_cidr
      private = cidrsubnet(var.network_cidr, 8, 2)
    }
  }

  subnets = local.subnet_config[local.tier]

  # -------------------------------------------------------------------------
  # Cost Guardrail: Resource Counts
  # -------------------------------------------------------------------------
  # This report is used by the pre-apply validation to warn about
  # unexpected costs. It must accurately reflect what will be created.
  cost_report = {
    vm_count              = local.vm_count
    vm_size               = local.vm_size
    managed_disks         = local.vm_count # OS disks
    managed_disk_total_gb = local.vm_count * local.managed_disk_size
    data_disks            = local.tier != "economy" ? local.vm_count : 0
    nat_gateways          = local.enable_nat_gateway ? 1 : 0
    public_ips            = var.azure_public_ip_enabled ? local.vm_count : 0
    postgres_servers      = local.database_mode != "container" ? 1 : 0
    postgres_ha           = local.database_mode == "azure-flexible-ha" ? true : false
    aks_clusters          = var.enable_aks && local.tier == "enterprise" ? 1 : 0
    load_balancers        = local.load_balancer_type != "none" ? 1 : 0
    app_gateways          = local.app_gateway_enabled ? 1 : 0
    storage_accounts      = local.storage_account_enabled ? 1 : 0
    key_vaults            = local.key_vault_enabled ? 1 : 0
    managed_identities    = local.managed_identity_enabled ? 1 : 0
    log_analytics         = local.log_analytics_enabled ? 1 : 0
    app_insights          = local.app_insights_enabled ? 1 : 0
  }

  # Estimated monthly cost (rough, for guardrail reporting)
  # Prices are approximate East US rates as of 2026
  estimated_monthly_cost = (
    # VMs
    (local.tier == "economy" ? 30.0 :
      local.tier == "standard" ? 3 * 60.0 :
    6 * 140.0) +
    # Managed disks (OS)
    (local.vm_count * local.managed_disk_size * 0.08) +
    # Data disks (standard/enterprise)
    (local.tier != "economy" ? local.vm_count * local.managed_disk_size * 0.10 : 0) +
    # NAT Gateway
    (local.enable_nat_gateway ? 32.0 : 0) +
    # Public IPs
    (var.azure_public_ip_enabled ? local.vm_count * 3.60 : 0) +
    # Azure Database for PostgreSQL
    (local.database_mode == "azure-flexible" ? 12.0 :
    local.database_mode == "azure-flexible-ha" ? 200.0 : 0) +
    # Load Balancer
    (local.load_balancer_type == "basic" ? 0 :
    local.load_balancer_type == "standard" ? 18.0 : 0) +
    # App Gateway
    (local.app_gateway_enabled ? 140.0 : 0) +
    # Storage Account
    (local.storage_account_enabled ? 5.0 : 0) +
    # Key Vault
    (local.key_vault_enabled ? 1.0 : 0) +
    # Log Analytics
    (local.log_analytics_enabled ? 10.0 : 0) +
    # App Insights
    (local.app_insights_enabled ? 10.0 : 0)
  )

  # -------------------------------------------------------------------------
  # Economy Guardrail: Forbidden Resources
  # -------------------------------------------------------------------------
  # These resources must NEVER appear in an Economy deployment.
  # The validation in the root module checks these.
  economy_forbidden = {
    aks_enabled     = var.enable_aks
    app_gateway     = local.app_gateway_enabled
    nat_gateway     = local.enable_nat_gateway
    ha_postgres     = local.database_mode == "azure-flexible-ha"
    multi_vm        = local.vm_count > 1
    key_vault       = local.key_vault_enabled
    load_balancer   = local.load_balancer_type != "none"
    storage_account = local.storage_account_enabled
    log_analytics   = local.log_analytics_enabled
  }

  economy_violations = [
    for k, v in local.economy_forbidden : k if v == true
  ]
}
