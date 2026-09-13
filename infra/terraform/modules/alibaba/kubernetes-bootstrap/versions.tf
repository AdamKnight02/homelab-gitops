# =============================================================================
# Alibaba Cloud Kubernetes Bootstrap Module — Version Constraints
# =============================================================================

terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
