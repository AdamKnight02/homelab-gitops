# =============================================================================
# Shared Version Constraints
# =============================================================================
# This file defines the minimum Terraform and provider versions required
# across all cloud environments. Each root module references these constraints
# to ensure consistency.
#
# Philosophy:
#   - Pin to major versions for stability
#   - Allow minor/patch updates for security fixes
#   - Document why each version is chosen
# =============================================================================

terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  # Rationale: Terraform 1.10+ provides stable state encryption and improved
  # provider locking. We avoid 2.0 until it stabilizes.

  required_providers {
    # -------------------------------------------------------------------------
    # Random Provider
    # Used for: generating unique suffixes, passwords, pet names
    # -------------------------------------------------------------------------
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }

    # -------------------------------------------------------------------------
    # TLS Provider
    # Used for: generating private keys, CSRs, self-signed certificates
    # -------------------------------------------------------------------------
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }

    # -------------------------------------------------------------------------
    # Local Provider
    # Used for: writing files, local-exec provisioners
    # -------------------------------------------------------------------------
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }

    # -------------------------------------------------------------------------
    # Cloud-Init Provider
    # Used for: rendering cloud-init configurations for VM bootstrap
    # -------------------------------------------------------------------------
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3"
    }
  }
}
