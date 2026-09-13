# =============================================================================
# Alibaba Cloud Storage Module — Outputs
# =============================================================================

output "oss_bucket_name" {
  description = "Name of the OSS bucket (if created)"
  value       = var.create_oss_bucket ? alicloud_oss_bucket.main[0].bucket : null
}

output "oss_bucket_domain" {
  description = "Domain of the OSS bucket (if created)"
  value       = var.create_oss_bucket ? alicloud_oss_bucket.main[0].extranet_endpoint : null
}

output "oss_bucket_intranet_endpoint" {
  description = "Intranet endpoint of the OSS bucket (if created)"
  value       = var.create_oss_bucket ? alicloud_oss_bucket.main[0].intranet_endpoint : null
}

output "nas_file_system_id" {
  description = "ID of the NAS file system (if created)"
  value       = var.create_nas ? alicloud_nas_file_system.main[0].id : null
}

output "nas_mount_target_domain" {
  description = "Mount target domain of the NAS file system (if created)"
  value       = var.create_nas ? alicloud_nas_mount_target.main[0].mount_target_domain : null
}
