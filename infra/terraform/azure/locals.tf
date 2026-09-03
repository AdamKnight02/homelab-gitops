# Local Values

locals {
  # Common tags
  common_tags = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
    ephemeral   = "true"
    owner       = "homelab"
    created_by  = "terraform"
    repository  = "https://github.com/AdamKnight02/homelab-gitops"
  }

  # Naming
  name_prefix = "${var.project_name}-${var.environment}"

  # Cloud-init script for K3s + Argo CD bootstrap
  cloud_init = templatefile("${path.module}/cloud-init.yaml", {
    public_ip = "$(curl -s ifconfig.me)"
  })
}
