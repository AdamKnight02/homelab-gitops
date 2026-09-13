# =============================================================================
# Common Outputs
# =============================================================================
# These outputs provide standardized information about deployed infrastructure.
# Each root module should output these values for consistency.
# =============================================================================

# ---------------------------------------------------------------------------
# Infrastructure Identity
# ---------------------------------------------------------------------------
output "project_name" {
  description = "The project name used for this deployment."
  value       = var.project_name
}

output "environment" {
  description = "The environment identifier."
  value       = var.environment
}

output "cloud_provider" {
  description = "The cloud provider for this deployment (azure or aws)."
  value       = "unknown" # Override in root module
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
output "network_cidr" {
  description = "The CIDR block of the deployed network."
  value       = var.network_cidr
}

output "subnet_cidr" {
  description = "The CIDR block of the deployed subnet."
  value       = var.subnet_cidr
}

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------
output "vm_public_ips" {
  description = "Public IP addresses of deployed VMs (if any)."
  value       = []
  sensitive   = false
}

output "vm_private_ips" {
  description = "Private IP addresses of deployed VMs."
  value       = []
  sensitive   = false
}

# ---------------------------------------------------------------------------
# Kubernetes
# ---------------------------------------------------------------------------
output "k3s_kubeconfig_command" {
  description = "Command to retrieve K3s kubeconfig from the VM."
  value       = "ssh <user>@<vm-ip> 'sudo cat /etc/rancher/k3s/k3s.yaml'"
}

output "argocd_url" {
  description = "URL to access Argo CD (once port-forward or ingress is configured)."
  value       = "https://argocd.localhost"
}

output "argocd_initial_password_command" {
  description = "Command to retrieve initial Argo CD admin password."
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

# ---------------------------------------------------------------------------
# Security Warnings
# ---------------------------------------------------------------------------
output "security_notes" {
  description = "Important security reminders about this deployment."
  value       = <<-EOT
    SECURITY REMINDERS:
    - Default Argo CD password is auto-generated; change it immediately
    - SSH access is restricted by allow_ssh_cidr (empty = no inbound SSH)
    - All resources are tagged as ephemeral=true; destroy when done
    - Terraform state contains sensitive data; do not commit it
    - Use cloud serial console or bastion host for VM access
    EOT
}

# ---------------------------------------------------------------------------
# Cost
# ---------------------------------------------------------------------------
output "estimated_monthly_cost_usd" {
  description = "Estimated monthly cost if left running (for awareness only)."
  value       = "See cost-analysis.md for detailed breakdown"
}
