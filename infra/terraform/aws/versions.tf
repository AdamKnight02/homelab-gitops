# =============================================================================
# AWS Root Module — Version Constraints
# =============================================================================
# This root module deploys the PKI lab to AWS.
# AWS may be PLAN-ONLY or ephemeral free-tier test (TBD by Access Auditor).
# =============================================================================

terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      # Rationale: AWS provider 5.x is current stable with improved
      # tagging support and default_tags configuration
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3"
    }
  }
}

provider "aws" {
  # Region configured via var.aws_region or AWS_DEFAULT_REGION
  # Credentials via environment variables, shared credentials, or IAM role

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = var.managed_by
      Owner       = var.owner
      Ephemeral   = var.ephemeral ? "true" : "false"
      CostCenter  = var.cost_center
    }
  }
}
