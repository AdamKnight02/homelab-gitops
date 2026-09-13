# =============================================================================
# Azure Kubernetes Bootstrap Module — Outputs
# =============================================================================

output "cloud_init_configs" {
  description = "List of cloud-init configurations (one per instance)"
  value       = local.cloud_init_configs
}

output "node_roles" {
  description = "List of node roles (server/agent)"
  value       = local.node_roles
}
