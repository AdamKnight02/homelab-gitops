# =============================================================================
# Alibaba Cloud Tier Configuration Module — Outputs
# =============================================================================

output "tier" {
  description = "Resolved service tier (lowercase)"
  value       = local.tier
}

output "instance_count" {
  description = "Number of ECS instances for this tier"
  value       = local.instance_count
}

output "instance_type" {
  description = "ECS instance type for this tier"
  value       = local.instance_type
}

output "multi_zone" {
  description = "Whether multi-zone deployment is enabled"
  value       = local.multi_zone
}

output "zone_count" {
  description = "Number of zones to deploy across"
  value       = local.zone_count
}

output "enable_nat_gateway" {
  description = "Whether NAT gateway is enabled"
  value       = local.enable_nat_gateway
}

output "enable_eip" {
  description = "Whether Elastic IP is enabled"
  value       = local.enable_eip
}

output "load_balancer_type" {
  description = "Load balancer type (none, nlb, slb)"
  value       = local.load_balancer_type
}

output "database_mode" {
  description = "Database mode (container, rds, rds-multi-zone)"
  value       = local.database_mode
}

output "rds_instance_type" {
  description = "RDS instance type (null for container mode)"
  value       = local.rds_instance_type
}

output "oss_enabled" {
  description = "Whether OSS bucket is enabled"
  value       = local.oss_enabled
}

output "oss_versioning" {
  description = "Whether OSS versioning is enabled"
  value       = local.oss_versioning
}

output "disk_size" {
  description = "System disk size in GB"
  value       = local.disk_size
}

output "disk_category" {
  description = "System disk category"
  value       = local.disk_category
}

output "kms_enabled" {
  description = "Whether KMS is enabled"
  value       = local.kms_enabled
}

output "secrets_manager_enabled" {
  description = "Whether Secrets Manager is enabled"
  value       = local.secrets_manager_enabled
}

output "detailed_monitoring" {
  description = "Whether detailed monitoring is enabled"
  value       = local.detailed_monitoring
}

output "cloudmonitor_enabled" {
  description = "Whether CloudMonitor is enabled"
  value       = local.cloudmonitor_enabled
}

output "cost_report" {
  description = "Resource count summary for cost guardrail review"
  value       = local.cost_report
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost in USD (rough approximation)"
  value       = local.estimated_monthly_cost
}
