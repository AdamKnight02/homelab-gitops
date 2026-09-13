# =============================================================================
# AWS Root Module — Variables
# =============================================================================
# AWS-specific variables. Common variables are inherited from the shared
# module or redefined here with AWS-specific defaults.
# =============================================================================

# ---------------------------------------------------------------------------
# Service Tier (NEW — tier-driven composition)
# ---------------------------------------------------------------------------
variable "service_tier" {
  description = "Service tier: economy, standard, or enterprise. Controls resource count, HA, and features."
  type        = string
  default     = "economy"

  validation {
    condition     = contains(["economy", "standard", "enterprise"], lower(var.service_tier))
    error_message = "Service tier must be one of: economy, standard, enterprise."
  }
}

variable "enable_eks" {
  description = "Enable EKS instead of K3s (enterprise tier only, opt-in)."
  type        = bool
  default     = false
}

variable "aws_instance_type_override" {
  description = "Override the tier-default instance type. Empty string uses tier default."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# AWS Account and Region
# ---------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region for resource deployment."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be a valid region identifier (e.g., us-east-1)."
  }
}

variable "aws_profile" {
  description = "AWS CLI profile to use. If empty, uses default credentials chain."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Resource Naming
# ---------------------------------------------------------------------------
variable "name_prefix" {
  description = "Prefix for all AWS resource names."
  type        = string
  default     = "pki"
}

# ---------------------------------------------------------------------------
# Compute — EC2
# ---------------------------------------------------------------------------
variable "aws_instance_type" {
  description = "EC2 instance type. Default is t3.micro (free-tier eligible if available). Used when service_tier=economy."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium", "t2.micro", "t2.small", "m6i.large"], var.aws_instance_type)
    error_message = "Instance type must be a valid option for the selected tier."
  }
}

variable "aws_ami_owner" {
  description = "Owner ID for the base AMI. Default is Canonical (Ubuntu)."
  type        = string
  default     = "099720109477" # Canonical
}

variable "aws_ami_name_filter" {
  description = "Name filter for the base AMI."
  type        = string
  default     = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
}

variable "aws_admin_username" {
  description = "Admin username for the EC2 instance."
  type        = string
  default     = "ubuntu"
}

variable "aws_ssh_public_key" {
  description = "SSH public key for EC2 access. If empty, a new key pair is generated."
  type        = string
  default     = ""
}

variable "aws_root_volume_size" {
  description = "Root EBS volume size in GB. Tier defaults: economy=20, standard=50, enterprise=100."
  type        = number
  default     = 20

  validation {
    condition     = var.aws_root_volume_size >= 8 && var.aws_root_volume_size <= 500
    error_message = "Root volume must be between 8 and 500 GB."
  }
}

variable "aws_root_volume_type" {
  description = "Root EBS volume type. gp3 is preferred for cost/performance."
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp3", "gp2", "standard"], var.aws_root_volume_type)
    error_message = "Volume type must be gp3, gp2, or standard."
  }
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "aws_vpc_cidr" {
  description = "CIDR block for the AWS VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "aws_subnet_cidr" {
  description = "CIDR block for the AWS public subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "aws_availability_zone" {
  description = "Availability zone for the subnet. Auto-selected if empty."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Cost Control
# ---------------------------------------------------------------------------
variable "aws_associate_public_ip" {
  description = "Whether to associate a public IP. Disable to avoid cost and exposure."
  type        = bool
  default     = false
}

variable "aws_enable_monitoring" {
  description = "Enable detailed EC2 monitoring. Disabled for cost control."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# IAM
# ---------------------------------------------------------------------------
variable "aws_iam_role_name" {
  description = "Name of the IAM role for EC2 instance profile. Auto-generated if empty."
  type        = string
  default     = ""
}

variable "aws_create_iam_role" {
  description = "Whether to create a dedicated IAM role for the EC2 instance."
  type        = bool
  default     = true
}



# =============================================================================
# Common Variables (duplicated from shared module for standalone validation)
# =============================================================================

variable "project_name" {
  description = "Name of the project. Used in resource naming and tagging."
  type        = string
  default     = "pki-cloudlab"
}

variable "environment" {
  description = "Environment identifier."
  type        = string
  default     = "lab"
}

variable "owner" {
  description = "Email or identifier of the person/team responsible."
  type        = string
  default     = "homelab-admin"
}

variable "managed_by" {
  description = "Tool or process managing this resource."
  type        = string
  default     = "terraform"
}

variable "ephemeral" {
  description = "Whether this infrastructure is temporary."
  type        = bool
  default     = true
}

variable "cost_center" {
  description = "Cost center or budget code."
  type        = string
  default     = "homelab"
}

variable "network_cidr" {
  description = "CIDR block for the virtual network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the primary subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "allow_ssh_cidr" {
  description = "CIDR blocks allowed to SSH to VMs."
  type        = list(string)
  default     = []
}

variable "k3s_version" {
  description = "K3s release channel or version to install."
  type        = string
  default     = "v1.30"
}

variable "argocd_version" {
  description = "Argo CD version to install."
  type        = string
  default     = "v2.12"
}

variable "git_repo_url" {
  description = "Git repository URL for Argo CD to sync."
  type        = string
  default     = "https://github.com/AdamKnight02/homelab-gitops.git"
}

variable "git_target_revision" {
  description = "Git branch or tag for Argo CD to track."
  type        = string
  default     = "main"
}
