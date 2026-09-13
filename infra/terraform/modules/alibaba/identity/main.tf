# =============================================================================
# Alibaba Cloud Identity Module — Main Resources
# =============================================================================

# ---------------------------------------------------------------------------
# RAM Role for ECS Instances
# ---------------------------------------------------------------------------
resource "alicloud_ram_role" "main" {
  count = var.create_ram_role ? 1 : 0

  role_name = "${var.name}-role"
  assume_role_policy_document = jsonencode({
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = ["ecs.aliyuncs.com"]
      }
    }]
    Version = "1"
  })
  description = "RAM role for PKI platform ECS instances"
  force       = true
  tags        = var.tags
}

# ---------------------------------------------------------------------------
# Assume Role Policy Document
# Note: alicloud_ram_policy_document data source is not available in current provider
# Using jsonencode directly in the resource instead
# ---------------------------------------------------------------------------
# data "alicloud_ram_policy_document" "assume_role" {
#   statement {
#     effect = "Allow"
#     action = ["sts:AssumeRole"]
#     principal {
#       entity      = "Service"
#       identifiers = ["ecs.aliyuncs.com"]
#     }
#   }
# }

# ---------------------------------------------------------------------------
# Attach Policies to Role
# ---------------------------------------------------------------------------
resource "alicloud_ram_role_policy_attachment" "main" {
  for_each = var.create_ram_role ? toset(var.role_policy_arns) : []

  policy_name = split("/", each.value)[1]
  policy_type = split("/", each.value)[0] == "system" ? "System" : "Custom"
  role_name   = alicloud_ram_role.main[0].role_name
}

# ---------------------------------------------------------------------------
# Instance Profile (RAM Role Attachment)
# NOTE: Role-to-instance attachment is handled by the compute module via
# the role_name attribute on alicloud_instance. This avoids a circular
# dependency between identity and compute modules.
# ---------------------------------------------------------------------------
