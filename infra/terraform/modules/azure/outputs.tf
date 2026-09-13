# =============================================================================
# Azure Tier Config Module — Outputs
# =============================================================================
# Exposes all tier-resolved values for consumption by the root module.
# =============================================================================

output "tier" {
  description = "Resolved tier (lowercase)"
  value       = local.tier
}

output "vm_count" {
  description = "Number of VMs for this tier"
  value       = local.vm_count
}

output "vm_size" {
  description = "Azure VM size for this tier"
  value       = local.vm_size
}

output "availability_zones" {
  description = "Number of availability zones"
  value       = local.availability_zones
}

output "enable_nat_gateway" {
  description = "Whether NAT gateway is enabled"
  value       = local.enable_nat_gateway
}

output "enable_private_subnets" {
  description = "Whether private subnets are enabled"
  value       = local.enable_private_subnets
}

output "load_balancer_type" {
  description = "Load balancer type (none, basic, standard)"
  value       = local.load_balancer_type
}

output "app_gateway_enabled" {
  description = "Whether Application Gateway is enabled"
  value       = local.app_gateway_enabled
}

output "database_mode" {
  description = "Database deployment mode"
  value       = local.database_mode
}

output "postgres_sku" {
  description = "PostgreSQL SKU (null for container mode)"
  value       = local.postgres_sku
}

output "postgres_storage_mb" {
  description = "PostgreSQL storage in MB"
  value       = local.postgres_storage_mb
}

output "storage_account_enabled" {
  description = "Whether storage account is enabled"
  value       = local.storage_account_enabled
}

output "storage_replication" {
  description = "Storage replication type"
  value       = local.storage_replication
}

output "managed_disk_size" {
  description = "Managed disk size in GB"
  value       = local.managed_disk_size
}

output "managed_disk_type" {
  description = "Managed disk type"
  value       = local.managed_disk_type
}

output "key_vault_enabled" {
  description = "Whether Key Vault is enabled"
  value       = local.key_vault_enabled
}

output "key_vault_sku" {
  description = "Key Vault SKU"
  value       = local.key_vault_sku
}

output "managed_identity_enabled" {
  description = "Whether managed identity is enabled"
  value       = local.managed_identity_enabled
}

output "log_analytics_enabled" {
  description = "Whether Log Analytics is enabled"
  value       = local.log_analytics_enabled
}

output "app_insights_enabled" {
  description = "Whether Application Insights is enabled"
  value       = local.app_insights_enabled
}

output "subnets" {
  description = "Map of subnet names to CIDR blocks"
  value       = local.subnets
}

output "cost_report" {
  description = "Resource count report for cost guardrails"
  value       = local.cost_report
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost in USD"
  value       = local.estimated_monthly_cost
}

output "economy_violations" {
  description = "List of economy tier violations (should be empty)"
  value       = local.economy_violations
}
