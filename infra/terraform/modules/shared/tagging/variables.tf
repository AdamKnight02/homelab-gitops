# Shared Tagging Module
# Provides consistent tagging across all resources

variable "customer" {
  description = "Customer short name (e.g., acme-corp)"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
}

variable "component" {
  description = "Resource component name (e.g., pki, gateway, scep)"
  type        = string
}

variable "module_path" {
  description = "Terraform module path (e.g., azure/pki-vm)"
  type        = string
}

variable "additional_tags" {
  description = "Additional tags to merge with standard tags"
  type        = map(string)
  default     = {}
}
