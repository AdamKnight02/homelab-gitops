# =============================================================================
# AWS Root Module — Main Resources
# =============================================================================
# This module defines the AWS infrastructure for the PKI lab.
#
# TIER-DRIVEN COMPOSITION:
#   economy    → Uses inline resources below (single EC2, minimal cost)
#   standard   → Delegates to modules/aws/* (3-node K3s, NLB, RDS, S3)
#   enterprise → Delegates to modules/aws/* (6-node K3s, multi-AZ, full HA)
#
# The existing economy path is preserved unchanged for backward compatibility.
# =============================================================================

# ---------------------------------------------------------------------------
# Data Sources (shared across all tiers)
# ---------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------------------------------------------------------------------
# AMI Data Source
# Latest Ubuntu 22.04 LTS from Canonical
# ---------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = [var.aws_ami_owner]

  filter {
    name   = "name"
    values = [var.aws_ami_name_filter]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# =============================================================================
# ECONOMY TIER — Inline Resources (original implementation, unchanged)
# =============================================================================
# These resources are created ONLY when service_tier = "economy" (default).
# For standard/enterprise, the module composition below is used instead.
# =============================================================================

# ---------------------------------------------------------------------------
# VPC (economy only)
# ---------------------------------------------------------------------------
resource "aws_vpc" "main" {
  count = local.use_tier_modules ? 0 : 1

  cidr_block           = var.aws_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.network_tags, {
    Name = local.vpc_name
  })
}

# ---------------------------------------------------------------------------
# Internet Gateway (economy only)
# Required for outbound internet access (e.g., K3s package downloads).
# No NAT Gateway — single public subnet design keeps costs minimal.
# ---------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  count = local.use_tier_modules ? 0 : 1

  vpc_id = aws_vpc.main[0].id

  tags = merge(local.network_tags, {
    Name = local.igw_name
  })
}

# ---------------------------------------------------------------------------
# Public Subnet (economy only)
# ---------------------------------------------------------------------------
resource "aws_subnet" "main" {
  count = local.use_tier_modules ? 0 : 1

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = var.aws_subnet_cidr
  availability_zone       = coalesce(var.aws_availability_zone, data.aws_availability_zones.available.names[0])
  map_public_ip_on_launch = var.aws_associate_public_ip

  tags = merge(local.network_tags, {
    Name = local.subnet_name
    Type = "public"
  })
}

# ---------------------------------------------------------------------------
# Route Table (economy only)
# Single route table for public subnet.
# ---------------------------------------------------------------------------
resource "aws_route_table" "main" {
  count = local.use_tier_modules ? 0 : 1

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = merge(local.network_tags, {
    Name = local.route_table_name
  })
}

resource "aws_route_table_association" "main" {
  count = local.use_tier_modules ? 0 : 1

  subnet_id      = aws_subnet.main[0].id
  route_table_id = aws_route_table.main[0].id
}

# ---------------------------------------------------------------------------
# Security Group (economy only)
# Default: deny all inbound. SSH only if allow_ssh_cidr is specified.
# ---------------------------------------------------------------------------
resource "aws_security_group" "main" {
  count = local.use_tier_modules ? 0 : 1

  name        = local.security_group_name
  description = "Security group for PKI lab EC2 instance"
  vpc_id      = aws_vpc.main[0].id

  tags = merge(local.security_tags, {
    Name = local.security_group_name
  })

  # SSH access — only if explicitly allowed
  dynamic "ingress" {
    for_each = length(var.allow_ssh_cidr) > 0 ? var.allow_ssh_cidr : []
    content {
      description = "SSH from ${ingress.value}"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # Allow all outbound (required for package installation)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------------------------
# SSH Key Pair (all tiers — shared)
# ---------------------------------------------------------------------------
resource "aws_key_pair" "main" {
  key_name   = local.key_pair_name
  public_key = var.aws_ssh_public_key != "" ? var.aws_ssh_public_key : tls_private_key.ssh.public_key_openssh

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# IAM Role and Instance Profile (economy only)
# Minimal permissions: SSM for Session Manager access, CloudWatch read-only.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "main" {
  count = !local.use_tier_modules && var.aws_create_iam_role ? 1 : 0

  name               = local.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge(local.security_tags, {
    Name = local.iam_role_name
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count = !local.use_tier_modules && var.aws_create_iam_role ? 1 : 0

  role       = aws_iam_role.main[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_readonly" {
  count = !local.use_tier_modules && var.aws_create_iam_role ? 1 : 0

  role       = aws_iam_role.main[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

resource "aws_iam_instance_profile" "main" {
  count = !local.use_tier_modules && var.aws_create_iam_role ? 1 : 0

  name = local.iam_profile_name
  role = aws_iam_role.main[0].name

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# EC2 Instance (economy only)
# t3.micro for free-tier eligibility (if available).
# ---------------------------------------------------------------------------
resource "aws_instance" "main" {
  count = local.use_tier_modules ? 0 : 1

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.aws_instance_type
  subnet_id              = aws_subnet.main[0].id
  vpc_security_group_ids = [aws_security_group.main[0].id]
  key_name               = aws_key_pair.main.key_name
  iam_instance_profile   = var.aws_create_iam_role ? aws_iam_instance_profile.main[0].name : null

  associate_public_ip_address = var.aws_associate_public_ip
  monitoring                  = var.aws_enable_monitoring

  root_block_device {
    volume_size           = var.aws_root_volume_size
    volume_type           = var.aws_root_volume_type
    encrypted             = true
    delete_on_termination = true
    tags                  = local.common_tags
  }

  user_data = base64encode(local.cloud_init_config)

  tags = merge(local.compute_tags, {
    Name = local.instance_name
  })

  lifecycle {
    ignore_changes = [
      user_data, # Ignore changes to cloud-init after initial boot
    ]
  }
}

# =============================================================================
# STANDARD / ENTERPRISE TIER — Module Composition
# =============================================================================
# When service_tier is "standard" or "enterprise", the root module delegates
# to the modular composition in modules/aws/*. Each module is tier-aware
# and reads from the central tier-config.
# =============================================================================

# ---------------------------------------------------------------------------
# Tier Configuration (shared locals for all modules)
# ---------------------------------------------------------------------------
module "tier_config" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/aws/tier-config"

  service_tier               = var.service_tier
  aws_instance_type_override = var.aws_instance_type_override
  aws_associate_public_ip    = var.aws_associate_public_ip
  enable_eks                 = var.enable_eks
}

# ---------------------------------------------------------------------------
# Network Module (standard/enterprise)
# ---------------------------------------------------------------------------
module "network" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/aws/network"

  name_prefix             = local.name_prefix
  name_suffix             = local.name_suffix
  vpc_cidr                = var.aws_vpc_cidr
  availability_zones      = module.tier_config[0].azs
  enable_private_subnets  = module.tier_config[0].enable_private_subnets
  enable_nat_gateway      = module.tier_config[0].enable_nat_gateway
  map_public_ip_on_launch = var.aws_associate_public_ip
  tags                    = local.common_tags
}

# ---------------------------------------------------------------------------
# Security Module (standard/enterprise)
# ---------------------------------------------------------------------------
module "security" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/aws/security"

  name_prefix    = local.name_prefix
  name_suffix    = local.name_suffix
  vpc_id         = module.network[0].vpc_id
  vpc_cidr       = var.aws_vpc_cidr
  allow_ssh_cidr = var.allow_ssh_cidr
  service_tier   = lower(var.service_tier)
  tags           = local.common_tags
}

# ---------------------------------------------------------------------------
# Secrets Module (standard/enterprise) — KMS + Secrets Manager
# Must be created before identity and database (they reference KMS key)
# ---------------------------------------------------------------------------
module "secrets" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/aws/secrets"

  name_prefix             = local.name_prefix
  name_suffix             = local.name_suffix
  service_tier            = lower(var.service_tier)
  kms_enabled             = module.tier_config[0].kms_enabled
  secrets_manager_enabled = module.tier_config[0].secrets_manager_enabled
  tags                    = local.common_tags
}

# ---------------------------------------------------------------------------
# Storage Module (standard/enterprise) — S3
# ---------------------------------------------------------------------------
module "storage" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/aws/storage"

  name_prefix   = local.name_prefix
  name_suffix   = local.name_suffix
  service_tier  = lower(var.service_tier)
  s3_enabled    = module.tier_config[0].s3_enabled
  s3_versioning = module.tier_config[0].s3_versioning
  kms_key_arn   = module.tier_config[0].kms_enabled ? module.secrets[0].kms_key_arn : null
  tags          = local.common_tags
}

# ---------------------------------------------------------------------------
# Identity Module (standard/enterprise) — IAM roles and policies
# ---------------------------------------------------------------------------
module "identity" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/aws/identity"

  name_prefix   = local.name_prefix
  name_suffix   = local.name_suffix
  service_tier  = lower(var.service_tier)
  s3_bucket_arn = module.tier_config[0].s3_enabled ? module.storage[0].s3_bucket_arn : null
  kms_key_arn   = module.tier_config[0].kms_enabled ? module.secrets[0].kms_key_arn : null
  tags          = local.common_tags
}

# ---------------------------------------------------------------------------
# Database Module (standard/enterprise) — RDS PostgreSQL
# ---------------------------------------------------------------------------
module "database" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/aws/database"

  name_prefix        = local.name_prefix
  name_suffix        = local.name_suffix
  service_tier       = lower(var.service_tier)
  database_mode      = module.tier_config[0].database_mode
  instance_class     = module.tier_config[0].rds_instance_class
  subnet_ids         = module.tier_config[0].enable_private_subnets ? module.network[0].private_subnet_ids : module.network[0].public_subnet_ids
  security_group_ids = [module.security[0].rds_security_group_id]
  availability_zones = module.tier_config[0].azs
  kms_key_arn        = module.tier_config[0].kms_enabled ? module.secrets[0].kms_key_arn : null
  tags               = local.common_tags
}

# ---------------------------------------------------------------------------
# Kubernetes Bootstrap Module (standard/enterprise) — Cloud-init templates
# ---------------------------------------------------------------------------
module "kubernetes_bootstrap" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/aws/kubernetes-bootstrap"

  name_prefix         = local.name_prefix
  name_suffix         = local.name_suffix
  service_tier        = lower(var.service_tier)
  admin_username      = var.aws_admin_username
  ssh_public_key      = var.aws_ssh_public_key != "" ? var.aws_ssh_public_key : tls_private_key.ssh.public_key_openssh
  k3s_version         = var.k3s_version
  argocd_version      = var.argocd_version
  git_repo_url        = var.git_repo_url
  git_target_revision = var.git_target_revision
  instance_count      = module.tier_config[0].instance_count
  server_private_ip   = "" # Will be set after server instance is created (chicken-and-egg: agents use SSM for token)
  s3_bucket_name      = module.tier_config[0].s3_enabled ? module.storage[0].s3_bucket_id : ""
  db_endpoint         = module.tier_config[0].database_mode != "container" ? module.database[0].db_endpoint : ""
  db_password         = module.tier_config[0].database_mode != "container" ? module.database[0].db_password : ""
  kms_key_arn         = module.tier_config[0].kms_enabled ? module.secrets[0].kms_key_arn : ""
  tags                = local.common_tags
}

# ---------------------------------------------------------------------------
# Compute Module (standard/enterprise) — EC2 instances for K3s
# ---------------------------------------------------------------------------
module "compute" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/aws/compute"

  name_prefix          = local.name_prefix
  name_suffix          = local.name_suffix
  service_tier         = lower(var.service_tier)
  instance_count       = module.tier_config[0].instance_count
  instance_type        = module.tier_config[0].instance_type
  ami_id               = data.aws_ami.ubuntu.id
  subnet_ids           = module.network[0].public_subnet_ids
  security_group_ids   = [module.security[0].k3s_security_group_id]
  key_name             = aws_key_pair.main.key_name
  iam_instance_profile = module.identity[0].instance_profile_name
  associate_public_ip  = var.aws_associate_public_ip
  enable_monitoring    = module.tier_config[0].detailed_monitoring
  root_volume_size     = module.tier_config[0].ebs_volume_size
  root_volume_type     = var.aws_root_volume_type
  user_data            = module.kubernetes_bootstrap[0].server_user_data
  availability_zones   = module.tier_config[0].azs
  tags                 = local.common_tags
}

# ---------------------------------------------------------------------------
# Load Balancer Module (standard/enterprise)
# ---------------------------------------------------------------------------
module "load_balancer" {
  count  = local.use_tier_modules ? 1 : 0
  source = "../modules/aws/load-balancer"

  name_prefix        = local.name_prefix
  name_suffix        = local.name_suffix
  service_tier       = lower(var.service_tier)
  load_balancer_type = module.tier_config[0].load_balancer_type
  vpc_id             = module.network[0].vpc_id
  subnet_ids         = module.network[0].public_subnet_ids
  security_group_ids = [module.security[0].lb_security_group_id]
  instance_ids       = module.compute[0].instance_ids
  tags               = local.common_tags
}
