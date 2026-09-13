# =============================================================================
# Azure Root Module — Version Constraints
# =============================================================================
# This root module deploys the PKI lab to Azure.
# It is PLAN-ONLY — no resources will be created during this project.
# =============================================================================

terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
      # Rationale: azurerm 4.x is the current stable major version
      # with improved resource provider registration handling
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
      # For Entra ID resources (service principals, managed identities)
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

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
      # Lab convenience: allow destroying non-empty resource groups
    }
  }
}
