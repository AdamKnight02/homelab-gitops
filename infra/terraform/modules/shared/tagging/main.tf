# Shared Tagging Module
# Generates standardized tags for all resources

locals {
  tags = merge(
    {
      customer         = var.customer
      environment      = var.environment
      component        = var.component
      managed-by       = "terraform"
      terraform-module = var.module_path
    },
    var.additional_tags
  )
}
