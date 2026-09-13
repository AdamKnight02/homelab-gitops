# =============================================================================
# AWS Kubernetes Bootstrap Module
# =============================================================================
# Tier-aware cloud-init templates for K3s installation.
# Economy: single-node K3s server.
# Standard: 1 server + 2 agents, multi-node K3s.
# Enterprise: 3 servers (HA) + 3+ agents, multi-AZ K3s.
# =============================================================================

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
variable "name_prefix" { type = string }
variable "name_suffix" { type = string }
variable "service_tier" { type = string }
variable "admin_username" { type = string }
variable "ssh_public_key" { type = string }
variable "k3s_version" { type = string }
variable "argocd_version" { type = string }
variable "git_repo_url" { type = string }
variable "git_target_revision" { type = string }
variable "instance_count" { type = number }
variable "server_private_ip" {
  type    = string
  default = ""
}
variable "s3_bucket_name" {
  type    = string
  default = ""
}
variable "db_endpoint" {
  type    = string
  default = ""
}
variable "db_password" {
  type      = string
  default   = ""
  sensitive = true
}
variable "kms_key_arn" {
  type    = string
  default = ""
}
variable "tags" { type = map(string) }

# ---------------------------------------------------------------------------
# Cloud-Init Template — Server (node 0)
# ---------------------------------------------------------------------------
locals {
  # Determine K3s server flags based on tier
  k3s_server_flags = var.service_tier == "economy" ? (
    "--disable=traefik --disable=servicelb --write-kubeconfig-mode=644"
    ) : var.service_tier == "standard" ? (
    "--disable=traefik --disable=servicelb --write-kubeconfig-mode=644"
    ) : (
    "--disable=traefik --disable=servicelb --write-kubeconfig-mode=644"
  )

  # TLS SANs for multi-node access
  k3s_tls_sans = var.service_tier != "economy" ? (
    "--tls-san=${var.server_private_ip}"
  ) : ""

  # Datastore endpoint for standard+ (external RDS)
  k3s_datastore = var.db_endpoint != "" ? (
    "--datastore-endpoint=postgres://pkiadmin:${var.db_password}@${var.db_endpoint}/pki"
  ) : ""

  # Server user data
  server_user_data = base64encode(templatefile("${path.module}/templates/cloud-init-server.yaml.tpl", {
    hostname            = "${var.name_prefix}-k3s-server-${var.name_suffix}"
    admin_username      = var.admin_username
    ssh_public_key      = var.ssh_public_key
    k3s_version         = var.k3s_version
    argocd_version      = var.argocd_version
    git_repo_url        = var.git_repo_url
    git_target_revision = var.git_target_revision
    service_tier        = var.service_tier
    k3s_server_flags    = local.k3s_server_flags
    k3s_tls_sans        = local.k3s_tls_sans
    k3s_datastore       = local.k3s_datastore
    s3_bucket_name      = var.s3_bucket_name
    instance_count      = var.instance_count
  }))

  # Agent user data (for nodes 1+)
  agent_user_data = base64encode(templatefile("${path.module}/templates/cloud-init-agent.yaml.tpl", {
    hostname          = "${var.name_prefix}-k3s-agent-${var.name_suffix}"
    name_prefix       = var.name_prefix
    admin_username    = var.admin_username
    ssh_public_key    = var.ssh_public_key
    k3s_version       = var.k3s_version
    server_private_ip = var.server_private_ip
    service_tier      = var.service_tier
  }))
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "server_user_data" {
  value = local.server_user_data
}

output "agent_user_data" {
  value = local.agent_user_data
}

output "k3s_kubeconfig_command" {
  value = var.service_tier == "economy" ? (
    "aws ssm start-session --target <instance-id> --document-name AWS-StartInteractiveCommand --parameters command='sudo cat /etc/rancher/k3s/k3s.yaml'"
    ) : (
    "ssh ${var.admin_username}@<server-ip> 'sudo cat /etc/rancher/k3s/k3s.yaml'"
  )
}
