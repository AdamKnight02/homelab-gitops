# =============================================================================
# AWS Tier Configuration
# =============================================================================
# Central tier-to-resource mapping. This file defines what each service tier
# means in terms of AWS infrastructure. All modules and the root module
# reference these locals to determine what to create.
#
# DESIGN PRINCIPLE: Tiers are intent declarations, not cloud SKUs.
# This file translates intent into AWS-specific resource decisions.
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
    economy    = "t3.micro"
    standard   = "t3.medium"
    enterprise = "m6i.large"
  }

  # Networking
  tier_multi_az = {
    economy    = false
    standard   = false
    enterprise = true
  }

  tier_nat_gateway = {
    economy    = false
    standard   = false
    enterprise = true
  }

  tier_private_subnets = {
    economy    = false
    standard   = false
    enterprise = true
  }

  # Load Balancer
  tier_load_balancer = {
    economy    = "none" # No LB — NodePort only
    standard   = "nlb"  # Network Load Balancer
    enterprise = "nlb"  # NLB (ALB optional via var)
  }

  # Database
  tier_database = {
    economy    = "container"    # PostgreSQL in container on K3s node
    standard   = "rds"          # RDS single-AZ
    enterprise = "rds-multi-az" # RDS Multi-AZ
  }

  tier_rds_instance_class = {
    economy    = null
    standard   = "db.t3.micro"
    enterprise = "db.r6g.large"
  }

  # Storage
  tier_s3_enabled = {
    economy    = false
    standard   = true
    enterprise = true
  }

  tier_s3_versioning = {
    economy    = false
    standard   = false
    enterprise = true
  }

  tier_ebs_volume_size = {
    economy    = 20
    standard   = 50
    enterprise = 100
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

  tier_cloudwatch_logs = {
    economy    = false
    standard   = true
    enterprise = true
  }

  # EKS (optional alternative to K3s for enterprise)
  tier_eks_enabled = {
    economy    = false
    standard   = false
    enterprise = false # EKS is opt-in via var.enable_eks
  }

  # -------------------------------------------------------------------------
  # Resolved Values (after tier lookup)
  # -------------------------------------------------------------------------
  instance_count          = local.tier_instance_count[local.tier]
  instance_type           = var.aws_instance_type_override != "" ? var.aws_instance_type_override : local.tier_instance_type[local.tier]
  multi_az                = local.tier_multi_az[local.tier]
  enable_nat_gateway      = local.tier_nat_gateway[local.tier]
  enable_private_subnets  = local.tier_private_subnets[local.tier]
  load_balancer_type      = local.tier_load_balancer[local.tier]
  database_mode           = local.tier_database[local.tier]
  rds_instance_class      = local.tier_rds_instance_class[local.tier]
  s3_enabled              = local.tier_s3_enabled[local.tier]
  s3_versioning           = local.tier_s3_versioning[local.tier]
  ebs_volume_size         = local.tier_ebs_volume_size[local.tier]
  kms_enabled             = local.tier_kms_enabled[local.tier]
  secrets_manager_enabled = local.tier_secrets_manager[local.tier]
  detailed_monitoring     = local.tier_detailed_monitoring[local.tier]
  cloudwatch_logs         = local.tier_cloudwatch_logs[local.tier]

  # -------------------------------------------------------------------------
  # Subnet Configuration by Tier
  # -------------------------------------------------------------------------
  # Economy:    1 public subnet
  # Standard:   1 public subnet (multi-node K3s, all in one AZ for cost)
  # Enterprise: 3 public + 3 private subnets across 3 AZs

  az_count = local.multi_az ? 3 : 1
  azs      = slice(data.aws_availability_zones.available.names, 0, local.az_count)

  # -------------------------------------------------------------------------
  # Cost Guardrail: Resource Counts
  # -------------------------------------------------------------------------
  cost_report = {
    ec2_instances   = local.instance_count
    ebs_volumes     = local.instance_count # root volumes
    ebs_total_gb    = local.instance_count * local.ebs_volume_size
    nat_gateways    = local.enable_nat_gateway ? local.az_count : 0
    public_ips      = var.aws_associate_public_ip ? local.instance_count : 0
    rds_instances   = local.database_mode != "container" ? 1 : 0
    rds_multi_az    = local.database_mode == "rds-multi-az" ? true : false
    eks_clusters    = var.enable_eks && local.tier == "enterprise" ? 1 : 0
    load_balancers  = local.load_balancer_type != "none" ? 1 : 0
    s3_buckets      = local.s3_enabled ? 1 : 0
    kms_keys        = local.kms_enabled ? 1 : 0
    secrets_manager = local.secrets_manager_enabled ? 1 : 0
  }

  # Estimated monthly cost (rough, for guardrail reporting)
  estimated_monthly_cost = (
    # EC2
    (local.tier == "economy" ? 8.50 : local.tier == "standard" ? 3 * 30.0 : 6 * 70.0) +
    # EBS
    (local.instance_count * local.ebs_volume_size * 0.08) +
    # NAT Gateway
    (local.enable_nat_gateway ? local.az_count * 32.0 : 0) +
    # Public IPs
    (var.aws_associate_public_ip ? local.instance_count * 3.60 : 0) +
    # RDS
    (local.database_mode == "rds" ? 15.0 : local.database_mode == "rds-multi-az" ? 60.0 : 0) +
    # NLB
    (local.load_balancer_type != "none" ? 16.0 : 0) +
    # S3
    (local.s3_enabled ? 5.0 : 0) +
    # KMS
    (local.kms_enabled ? 1.0 : 0) +
    # Secrets Manager
    (local.secrets_manager_enabled ? 0.40 : 0)
  )
}
