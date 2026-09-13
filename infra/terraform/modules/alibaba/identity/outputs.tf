# =============================================================================
# Alibaba Cloud Identity Module — Outputs
# =============================================================================

output "ram_role_name" {
  description = "Name of the RAM role (if created)"
  value       = var.create_ram_role ? alicloud_ram_role.main[0].role_name : null
}

output "ram_role_arn" {
  description = "ARN of the RAM role (if created)"
  value       = var.create_ram_role ? alicloud_ram_role.main[0].arn : null
}

output "ram_role_id" {
  description = "ID of the RAM role (if created)"
  value       = var.create_ram_role ? alicloud_ram_role.main[0].id : null
}
