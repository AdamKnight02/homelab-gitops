# =============================================================================
# Azure Remote State Backend — Backend Configuration
# =============================================================================
# This file configures the Azure Blob Storage backend for Terraform state.
# It should be used AFTER the bootstrap layer has created the state
# infrastructure.
#
# USAGE:
#   terraform init -backend-config=backend.hcl
#
# MIGRATION:
#   terraform init -migrate-state -backend-config=backend.hcl
# =============================================================================

terraform {
  # Backend configuration is intentionally commented out for plan-only validation.
  # Uncomment and configure backend.hcl for remote state in real deployments.
  # backend "azurerm" {
  #   # Configuration loaded from backend.hcl
  #   # via: terraform init -backend-config=backend.hcl
  # }
}
