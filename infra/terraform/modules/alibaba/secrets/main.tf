# =============================================================================
# Alibaba Cloud Secrets Module — Main Resources
# =============================================================================

# ---------------------------------------------------------------------------
# KMS Key
# ---------------------------------------------------------------------------
resource "alicloud_kms_key" "main" {
  count = var.create_kms_key ? 1 : 0

  description        = "${var.name} KMS key"
  key_usage          = var.kms_key_usage
  key_spec           = var.kms_key_spec
  status             = "Enabled"
  automatic_rotation = "Enabled"

  tags = var.tags
}

# ---------------------------------------------------------------------------
# KMS Alias
# ---------------------------------------------------------------------------
resource "alicloud_kms_alias" "main" {
  count = var.create_kms_key ? 1 : 0

  alias_name = "alias/${var.name}-key"
  key_id     = alicloud_kms_key.main[0].id
}

# ---------------------------------------------------------------------------
# Secrets Manager Secret
# Note: alicloud_secretsmanager_secret is not available in the current provider version
# Using alicloud_kms_secret instead
# ---------------------------------------------------------------------------
resource "alicloud_kms_secret" "main" {
  count = var.create_secret ? 1 : 0

  secret_name = var.secret_name != "" ? var.secret_name : "${var.name}-secret"
  description = "${var.name} secret"
  secret_type = var.secret_type
  secret_data = var.secret_data != "" ? var.secret_data : "{}"
  version_id  = "v1"

  tags = var.tags
}
