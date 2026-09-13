# =============================================================================
# Alibaba Cloud Secrets Module — Outputs
# =============================================================================

output "kms_key_id" {
  description = "ID of the KMS key (if created)"
  value       = var.create_kms_key ? alicloud_kms_key.main[0].id : null
}

output "kms_key_arn" {
  description = "ARN of the KMS key (if created)"
  value       = var.create_kms_key ? alicloud_kms_key.main[0].arn : null
}

output "kms_alias_name" {
  description = "Alias name of the KMS key (if created)"
  value       = var.create_kms_key ? alicloud_kms_alias.main[0].alias_name : null
}

output "secret_name" {
  description = "Name of the secret (if created)"
  value       = var.create_secret ? alicloud_kms_secret.main[0].secret_name : null
}

output "secret_arn" {
  description = "ARN of the secret (if created)"
  value       = var.create_secret ? alicloud_kms_secret.main[0].arn : null
}
