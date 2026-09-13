# =============================================================================
# Azure Remote State Backend — Bootstrap Layer
# =============================================================================
# This file defines the Azure Storage Account and Blob Container used for
# Terraform remote state. It is designed to be applied ONCE per environment
# before any other Terraform modules are initialized with remote state.
#
# COST OPTIMIZATION: Uses Standard LRS storage with minimal redundancy
# for lab/dev environments. Enterprise should use ZRS or GRS.
#
# SECURITY: TLS 1.2+ enforced, blob encryption at rest, RBAC-ready,
# versioning enabled, soft delete enabled.
# =============================================================================

terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

# -----------------------------------------------------------------------------
# Random Suffix for Globally Unique Storage Account Name
# -----------------------------------------------------------------------------
resource "random_string" "state_suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

# -----------------------------------------------------------------------------
# Resource Group for State Infrastructure
# -----------------------------------------------------------------------------
resource "azurerm_resource_group" "state" {
  name     = "${var.name_prefix}-state-rg-${var.environment}"
  location = var.azure_region
  tags     = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Storage Account for Terraform State
# -----------------------------------------------------------------------------
# Naming: {prefix}state{suffix} — must be globally unique, 3-24 chars,
# lowercase letters and numbers only.
# -----------------------------------------------------------------------------
resource "azurerm_storage_account" "state" {
  name                     = "${replace(var.name_prefix, "-", "")}state${random_string.state_suffix.result}"
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = var.storage_replication_type
  account_kind             = "StorageV2"

  # Security: Enforce TLS 1.2+
  min_tls_version = "TLS1_2"

  # Security: Disable shared key access (use Azure AD / RBAC)
  shared_access_key_enabled = false

  # Security: Disable public blob access
  allow_nested_items_to_be_public = false

  # Security: Enable blob encryption at rest (Microsoft-managed keys)
  # For customer-managed keys, use azurerm_storage_account_customer_managed_key
  blob_properties {
    # Versioning for state recovery
    versioning_enabled = true

    # Soft delete for accidental deletion protection
    delete_retention_policy {
      days = var.soft_delete_retention_days
    }

    # Container soft delete
    container_delete_retention_policy {
      days = var.soft_delete_retention_days
    }

    # Change feed for audit logging
    change_feed_enabled = true
  }

  # Network rules: Deny by default, allow only from specified IPs/VNets
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    ip_rules                   = var.allowed_ip_ranges
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }

  tags = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Blob Container for Terraform State
# -----------------------------------------------------------------------------
resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Blob Container for State Backups
# -----------------------------------------------------------------------------
resource "azurerm_storage_container" "state_backups" {
  name                  = "state-backups"
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Blob Container for State Locks (metadata)
# -----------------------------------------------------------------------------
# Note: Azure Blob Storage uses blob leases for locking, not a separate table.
# This container stores lock metadata and migration markers.
# -----------------------------------------------------------------------------
resource "azurerm_storage_container" "state_locks" {
  name                  = "state-locks"
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Role Assignment: Terraform Service Principal
# -----------------------------------------------------------------------------
# Grants the Terraform service principal Storage Blob Data Contributor
# on the state storage account. Required for state operations.
# -----------------------------------------------------------------------------
resource "azurerm_role_assignment" "terraform_state_contributor" {
  count = var.terraform_sp_object_id != "" ? 1 : 0

  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.terraform_sp_object_id
}

# -----------------------------------------------------------------------------
# Role Assignment: Current User (for bootstrap operations)
# -----------------------------------------------------------------------------
data "azuread_client_config" "current" {}

resource "azurerm_role_assignment" "current_user_state_contributor" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_client_config.current.object_id
}

# -----------------------------------------------------------------------------
# Management Lock: Prevent Accidental Deletion
# -----------------------------------------------------------------------------
resource "azurerm_management_lock" "state_storage" {
  name       = "state-storage-lock"
  scope      = azurerm_storage_account.state.id
  lock_level = "CanNotDelete"
  notes      = "Protects Terraform state storage from accidental deletion. Remove manually if decommissioning."
}

# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "terraform-state"
    Component   = "bootstrap"
  }
}
