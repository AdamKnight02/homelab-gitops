# =============================================================================
# AWS Secrets Module
# =============================================================================
# Tier-aware KMS keys and Secrets Manager.
# Economy: no KMS, no Secrets Manager (OpenBao standalone on K3s).
# Standard: no KMS, no Secrets Manager (OpenBao HA on K3s).
# Enterprise: KMS key for encryption at rest, Secrets Manager for credentials.
# =============================================================================

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
variable "name_prefix" { type = string }
variable "name_suffix" { type = string }
variable "service_tier" { type = string }
variable "kms_enabled" { type = bool }
variable "secrets_manager_enabled" { type = bool }
variable "tags" { type = map(string) }

# ---------------------------------------------------------------------------
# KMS Key (Enterprise only)
# ---------------------------------------------------------------------------
resource "aws_kms_key" "main" {
  count = var.kms_enabled ? 1 : 0

  description             = "KMS key for ${var.name_prefix} encryption at rest"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-kms-${var.name_suffix}"
    Tier = var.service_tier
  })
}

resource "aws_kms_alias" "main" {
  count = var.kms_enabled ? 1 : 0

  name          = "alias/${var.name_prefix}-${var.name_suffix}"
  target_key_id = aws_kms_key.main[0].key_id
}

# ---------------------------------------------------------------------------
# Secrets Manager — Database Credentials (Enterprise only)
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "db_credentials" {
  count = var.secrets_manager_enabled ? 1 : 0

  name                    = "${var.name_prefix}/db/credentials-${var.name_suffix}"
  description             = "RDS PostgreSQL credentials for PKI platform"
  kms_key_id              = var.kms_enabled ? aws_kms_key.main[0].arn : null
  recovery_window_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-creds-${var.name_suffix}"
    Tier = var.service_tier
  })
}

# Placeholder — actual secret value set after RDS creation
resource "aws_secretsmanager_secret_version" "db_credentials" {
  count = var.secrets_manager_enabled ? 1 : 0

  secret_id = aws_secretsmanager_secret.db_credentials[0].id
  secret_string = jsonencode({
    username = "PLACEHOLDER"
    password = "PLACEHOLDER"
    engine   = "postgres"
    host     = "PLACEHOLDER"
    port     = 5432
    dbname   = "pki"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ---------------------------------------------------------------------------
# Secrets Manager — OpenBao Unseal Keys (Enterprise only)
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "openbao_unseal" {
  count = var.secrets_manager_enabled ? 1 : 0

  name                    = "${var.name_prefix}/openbao/unseal-${var.name_suffix}"
  description             = "OpenBao unseal keys for PKI platform"
  kms_key_id              = var.kms_enabled ? aws_kms_key.main[0].arn : null
  recovery_window_in_days = 30

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bao-unseal-${var.name_suffix}"
    Tier = var.service_tier
  })
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "kms_key_id" {
  value = var.kms_enabled ? aws_kms_key.main[0].key_id : null
}

output "kms_key_arn" {
  value = var.kms_enabled ? aws_kms_key.main[0].arn : null
}

output "kms_alias_arn" {
  value = var.kms_enabled ? aws_kms_alias.main[0].arn : null
}

output "db_credentials_secret_arn" {
  value = var.secrets_manager_enabled ? aws_secretsmanager_secret.db_credentials[0].arn : null
}

output "openbao_unseal_secret_arn" {
  value = var.secrets_manager_enabled ? aws_secretsmanager_secret.openbao_unseal[0].arn : null
}
