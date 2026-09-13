# =============================================================================
# Azure Kubernetes Bootstrap Module — Main Resources
# =============================================================================
# Generates cloud-init configurations for K3s bootstrap on Azure VMs.
# Tier-aware: single-node for economy, multi-node for standard/enterprise.
# =============================================================================

# ---------------------------------------------------------------------------
# Cloud-Init Configurations (one per VM)
# ---------------------------------------------------------------------------
locals {
  # Determine node role based on index
  node_roles = [for i in range(var.instance_count) : i == 0 ? "server" : "agent"]

  # K3s server URL (first node's private IP)
  k3s_server_url = var.instance_count > 1 ? "https://${var.server_private_ip}:6443" : ""

  # Cloud-init configs
  cloud_init_configs = [for i in range(var.instance_count) : templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
    hostname              = "${var.name}-vm-${i}"
    admin_username        = var.admin_username
    ssh_public_key        = var.ssh_public_key
    k3s_version           = var.k3s_version
    argocd_version        = var.argocd_version
    git_repo_url          = var.git_repo_url
    git_target_revision   = var.git_target_revision
    node_role             = local.node_roles[i]
    node_index            = i
    k3s_server_url        = local.k3s_server_url
    k3s_token             = var.k3s_token
    enable_azure_csi      = var.enable_azure_csi
    enable_azure_ccm      = var.enable_azure_ccm
    azure_client_id       = var.azure_client_id
    azure_tenant_id       = var.azure_tenant_id
    azure_subscription_id = var.azure_subscription_id
    azure_resource_group  = var.azure_resource_group
    azure_vnet_name       = var.azure_vnet_name
    azure_subnet_name     = var.azure_subnet_name
    azure_nsg_name        = var.azure_nsg_name
    azure_lb_name         = var.azure_lb_name
  })]
}
