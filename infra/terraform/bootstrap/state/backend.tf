# =============================================================================
# Azure Remote State Backend — Bootstrap Configuration
# =============================================================================
# This file is used to initialize the bootstrap layer with a local backend.
# After the state infrastructure is created, migrate to remote state using:
#   terraform init -migrate-state -backend-config=backend.hcl
# =============================================================================

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
