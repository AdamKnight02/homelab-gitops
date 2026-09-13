# =============================================================================
# Shared Provider Configuration Template
# =============================================================================
# This file documents the provider configuration patterns used across
# Azure and AWS root modules. It is NOT a live provider configuration —
# each root module defines its own providers block.
#
# Design Principles:
#   - Each cloud gets its own root module (directory-based separation)
#   - No workspace-based environment switching (too error-prone for labs)
#   - Provider credentials come from environment variables or CLI auth
#   - Never hardcode credentials in Terraform files
# =============================================================================

# ---------------------------------------------------------------------------
# AZURE PROVIDER PATTERN (for infra/terraform/azure/)
# ---------------------------------------------------------------------------
# provider "azurerm" {
#   features {}
#   # Credentials via:
#   #   - AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_SUBSCRIPTION_ID, AZURE_TENANT_ID
#   #   - az login (interactive)
#   #   - Managed Identity (when running in Azure)
# }
#
# provider "azuread" {
#   # For Entra ID / Azure AD resources (service principals, app registrations)
#   # Uses same credentials as azurerm
# }

# ---------------------------------------------------------------------------
# AWS PROVIDER PATTERN (for infra/terraform/aws/)
# ---------------------------------------------------------------------------
# provider "aws" {
#   region = var.aws_region
#   # Credentials via:
#   #   - AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
#   #   - AWS_PROFILE
#   #   - EC2 Instance Profile / IAM Role
#   #   - aws configure
#   default_tags {
#     tags = local.common_tags
#   }
# }
