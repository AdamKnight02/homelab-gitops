# =============================================================================
# Alibaba Cloud Kubernetes Bootstrap Module — Main Resources
# =============================================================================

# ---------------------------------------------------------------------------
# Cloud-Init Configuration
# ---------------------------------------------------------------------------
locals {
  cloud_init_config = templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
    admin_username      = var.admin_username
    ssh_public_key      = var.ssh_public_key
    k3s_version         = var.k3s_version
    argocd_version      = var.argocd_version
    git_repo_url        = var.git_repo_url
    git_target_revision = var.git_target_revision
    hostname            = var.hostname
    server_url          = var.server_url
    token               = var.token
    is_server           = var.is_server
    disable_traefik     = var.disable_traefik
    disable_servicelb   = var.disable_servicelb
  })
}

# ---------------------------------------------------------------------------
# Local File (for debugging — optional)
# ---------------------------------------------------------------------------
resource "local_file" "cloud_init" {
  count = var.is_server ? 1 : 0

  content  = local.cloud_init_config
  filename = "${path.module}/.debug/cloud-init-${var.hostname}.yaml"
}
