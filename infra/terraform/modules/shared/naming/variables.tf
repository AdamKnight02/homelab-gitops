# Shared Naming Module
# Provides consistent naming conventions across all resources
# Pattern: <prefix>-<customer>-<environment>-<component>-<instance>

variable "cloud_prefix" {
  description = "Cloud provider abbreviation (e.g., az, aws, ali)"
  type        = string
}

variable "customer" {
  description = "Customer short name (e.g., acme-corp)"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
}

variable "environment_abbreviation" {
  description = "Short environment abbreviation (e.g., p, s, d)"
  type        = string
}

variable "component" {
  description = "Resource component name (e.g., pki, gateway, scep)"
  type        = string
}

variable "instance" {
  description = "Instance identifier (e.g., 01, primary, secondary)"
  type        = string
  default     = "01"
}
