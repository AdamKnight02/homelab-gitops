# =============================================================================
# Alibaba Cloud Security Module — Outputs
# =============================================================================

output "security_group_id" {
  description = "ID of the security group"
  value       = alicloud_security_group.main.id
}

output "security_group_name" {
  description = "Name of the security group"
  value       = alicloud_security_group.main.security_group_name
}
