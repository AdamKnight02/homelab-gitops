# =============================================================================
# Alibaba Cloud Database Module — Version Constraints
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
  }
}
