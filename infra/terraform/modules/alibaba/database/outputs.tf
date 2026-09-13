# =============================================================================
# Alibaba Cloud Database Module — Outputs
# =============================================================================

output "rds_instance_id" {
  description = "ID of the RDS instance (if created)"
  value       = var.create_rds ? alicloud_db_instance.main[0].id : null
}

output "rds_connection_string" {
  description = "Connection string for the RDS instance (if created)"
  value       = var.create_rds ? alicloud_db_instance.main[0].connection_string : null
}

output "rds_port" {
  description = "Port of the RDS instance (if created)"
  value       = var.create_rds ? alicloud_db_instance.main[0].port : null
}

output "database_name" {
  description = "Name of the database (if created)"
  value       = var.create_rds ? alicloud_db_database.main[0].data_base_name : null
}

output "database_account_name" {
  description = "Name of the database account (if created)"
  value       = var.create_rds ? alicloud_rds_account.main[0].account_name : null
}

output "database_connection_string" {
  description = "Full database connection string (if created, sensitive)"
  value       = local.connection_string
  sensitive   = true
}

output "ha_enabled" {
  description = "Whether HA is enabled"
  value       = var.ha_enabled
}
