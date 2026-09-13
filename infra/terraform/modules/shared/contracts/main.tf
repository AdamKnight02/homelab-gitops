# =============================================================================
# Terraform Provider Contract v1 — Shared Validation Module
# =============================================================================
# This module defines the contract version and validation logic that all
# cloud provider adapters (Azure, AWS, Alibaba) must implement.
#
# CONTRACT VERSION: v1
# =============================================================================

locals {
  # Contract version identifier
  provider_contract_version = "v1"

  # Required tags that every provider must apply to all resources
  required_tags = [
    "Project",
    "Environment",
    "ManagedBy",
    "Owner",
    "Ephemeral",
    "CostCenter"
  ]

  # Required outputs that every provider must expose
  required_outputs = [
    "cloud_provider",
    "service_tier",
    "ssh_private_key",
    "ssh_public_key",
    "estimated_monthly_cost_usd",
    "cost_report",
    "security_notes"
  ]

  # Required inputs that every provider must accept
  required_inputs = [
    "service_tier",
    "project_name",
    "environment",
    "owner",
    "managed_by",
    "ephemeral",
    "cost_center",
    "network_cidr",
    "subnet_cidr",
    "allow_ssh_cidr",
    "k3s_version",
    "argocd_version",
    "git_repo_url",
    "git_target_revision"
  ]

  # Valid service tiers
  valid_tiers = ["economy", "standard", "enterprise"]

  # Naming convention patterns per provider
  naming_patterns = {
    azure = {
      resource_group = "{prefix}-rg-{suffix}"
      vnet           = "{prefix}-vnet-{suffix}"
      subnet         = "{prefix}-subnet-{suffix}"
      nsg            = "{prefix}-nsg-{suffix}"
      vm             = "{prefix}-vm-{suffix}"
      disk           = "{prefix}-osdisk-{suffix}"
      key_vault      = "{prefix}-kv-{suffix}"
      storage        = "{prefix}st{suffix}"
    }
    aws = {
      vpc            = "{prefix}-vpc-{suffix}"
      subnet         = "{prefix}-subnet-{suffix}"
      security_group = "{prefix}-sg-{suffix}"
      instance       = "{prefix}-ec2-{suffix}"
      volume         = "{prefix}-vol-{suffix}"
      iam_role       = "{prefix}-role-{suffix}"
      key_pair       = "{prefix}-key-{suffix}"
      s3_bucket      = "{prefix}-s3-{suffix}"
    }
    alibaba = {
      vpc            = "{prefix}-vpc-{suffix}"
      vswitch        = "{prefix}-vsw-{suffix}"
      security_group = "{prefix}-sg-{suffix}"
      instance       = "{prefix}-ecs-{suffix}"
      disk           = "{prefix}-disk-{suffix}"
      ram_role       = "{prefix}-role-{suffix}"
      key_pair       = "{prefix}-key-{suffix}"
      oss_bucket     = "{prefix}-oss-{suffix}"
    }
  }

  # Tier capability matrix — what each tier must support
  tier_capabilities = {
    economy = {
      min_instances         = 1
      max_instances         = 1
      allow_public_ip       = true
      allow_nat_gateway     = false
      allow_private_subnets = false
      allow_load_balancer   = false
      allow_managed_db      = false
      allow_kms             = false
      allow_secrets_mgr     = false
      allow_monitoring      = false
      allow_multi_az        = false
    }
    standard = {
      min_instances         = 3
      max_instances         = 3
      allow_public_ip       = true
      allow_nat_gateway     = false
      allow_private_subnets = false
      allow_load_balancer   = true
      allow_managed_db      = true
      allow_kms             = false
      allow_secrets_mgr     = false
      allow_monitoring      = true
      allow_multi_az        = false
    }
    enterprise = {
      min_instances         = 6
      max_instances         = 6
      allow_public_ip       = true
      allow_nat_gateway     = true
      allow_private_subnets = true
      allow_load_balancer   = true
      allow_managed_db      = true
      allow_kms             = true
      allow_secrets_mgr     = true
      allow_monitoring      = true
      allow_multi_az        = true
    }
  }
}
