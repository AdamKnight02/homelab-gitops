# Shared Tags Module
# Provides consistent tagging across all cloud environments

locals {
  common_tags = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
    ephemeral   = "true"
    owner       = var.owner
    created_by  = "terraform"
    repository  = var.repository_url
  }
}

output "tags" {
  description = "Common tags to apply to all resources"
  value       = local.common_tags
}
