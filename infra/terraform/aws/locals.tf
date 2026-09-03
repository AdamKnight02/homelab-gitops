# Local Values

locals {
  # Common tags (merged with provider default_tags)
  common_tags = {
    environment = var.environment
    repository  = "https://github.com/AdamKnight02/homelab-gitops"
  }

  # Naming
  name_prefix = "${var.project_name}-${var.environment}"

  # Cloud-init script for K3s + Argo CD bootstrap
  cloud_init = templatefile("${path.module}/cloud-init.yaml", {})
}
