# =============================================================================
# Alibaba Cloud Root Module — Version Constraints
# =============================================================================
# This root module deploys the PKI platform to Alibaba Cloud.
# Alibaba Cloud is PLAN-ONLY (no credentials configured).
# =============================================================================

terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = "~> 1.200"
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
  }
}

provider "alicloud" {
  # Region configured via var.alibaba_region or ALICLOUD_REGION
  # Credentials via environment variables:
  #   ALICLOUD_ACCESS_KEY, ALICLOUD_SECRET_KEY
  # NOTE: No credentials are currently configured — plan-only mode.
}
