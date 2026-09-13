# =============================================================================
# Azure Remote State Backend — Bootstrap Variables
# =============================================================================

variable "project_name" {
  description = "Name of the project. Used in resource naming and tagging."
  type        = string
  default     = "pki-platform"
}

variable "environment" {
  description = "Environment identifier (lab, dev, staging, prod)."
  type        = string
  default     = "lab"

  validation {
    condition     = contains(["lab", "dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: lab, dev, staging, prod."
  }
}

variable "name_prefix" {
  description = "Prefix for all Azure resource names."
  type        = string
  default     = "pki"
}

variable "azure_region" {
  description = "Azure region for state infrastructure deployment."
  type        = string
  default     = "eastus"

  validation {
    condition     = contains(["eastus", "westus2", "westeurope", "northeurope", "centralus", "southcentralus"], var.azure_region)
    error_message = "Region must be a common Azure region."
  }
}

variable "storage_replication_type" {
  description = "Storage account replication type. LRS for lab/dev, ZRS for staging, GRS for prod."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "RAGRS"], var.storage_replication_type)
    error_message = "Replication type must be one of: LRS, ZRS, GRS, RAGRS."
  }
}

variable "soft_delete_retention_days" {
  description = "Number of days to retain soft-deleted blobs and containers."
  type        = number
  default     = 30

  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 365
    error_message = "Retention must be between 7 and 365 days."
  }
}

variable "allowed_ip_ranges" {
  description = "List of IP ranges allowed to access the state storage account."
  type        = list(string)
  default     = []
}

variable "allowed_subnet_ids" {
  description = "List of subnet IDs allowed to access the state storage account."
  type        = list(string)
  default     = []
}

variable "terraform_sp_object_id" {
  description = "Object ID of the Terraform service principal for RBAC. Leave empty to skip."
  type        = string
  default     = ""
}
