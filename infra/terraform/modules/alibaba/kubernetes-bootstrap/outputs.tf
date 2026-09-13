# =============================================================================
# Alibaba Cloud Kubernetes Bootstrap Module — Outputs
# =============================================================================

output "cloud_init_config" {
  description = "Rendered cloud-init configuration"
  value       = local.cloud_init_config
  sensitive   = true
}

output "cloud_init_base64" {
  description = "Base64-encoded cloud-init configuration"
  value       = base64encode(local.cloud_init_config)
  sensitive   = true
}
