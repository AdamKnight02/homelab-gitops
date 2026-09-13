# =============================================================================
# Tagging Strategy
# =============================================================================
# Consistent tagging across all cloud resources enables:
#   - Cost tracking and chargeback
#   - Resource inventory and discovery
#   - Automated cleanup of ephemeral resources
#   - Security auditing
#
# Every resource MUST include these tags/labels.
# =============================================================================

locals {
  # -------------------------------------------------------------------------
  # Common Tags (applied to ALL resources)
  # -------------------------------------------------------------------------
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.managed_by
    Owner       = var.owner
    Ephemeral   = var.ephemeral ? "true" : "false"
    CostCenter  = var.cost_center
    CreatedAt   = timestamp()
  }

  # -------------------------------------------------------------------------
  # Resource-Specific Tags (merged with common_tags as needed)
  # -------------------------------------------------------------------------
  compute_tags = merge(local.common_tags, {
    Component = "compute"
    Purpose   = "k3s-node"
  })

  network_tags = merge(local.common_tags, {
    Component = "network"
    Purpose   = "vpc-vnet"
  })

  storage_tags = merge(local.common_tags, {
    Component = "storage"
    Purpose   = "vm-disk"
  })

  security_tags = merge(local.common_tags, {
    Component = "security"
    Purpose   = "access-control"
  })

  # -------------------------------------------------------------------------
  # Kubernetes Labels (applied to K8s resources via cloud-init or manifests)
  # -------------------------------------------------------------------------
  k8s_labels = {
    "app.kubernetes.io/part-of"    = var.project_name
    "app.kubernetes.io/managed-by" = var.managed_by
    "environment"                  = var.environment
    "ephemeral"                    = var.ephemeral ? "true" : "false"
  }
}

# ---------------------------------------------------------------------------
# Tagging Rules
# ---------------------------------------------------------------------------
# 1. All resources MUST have Project, Environment, ManagedBy, Owner, Ephemeral
# 2. Ephemeral=true resources SHOULD be destroyed within 30 days
# 3. CostCenter enables budget tracking across cloud accounts
# 4. CreatedAt enables age-based cleanup policies
# 5. Component and Purpose provide additional granularity
# 6. NEVER tag with sensitive values (passwords, tokens, keys)
# ---------------------------------------------------------------------------
