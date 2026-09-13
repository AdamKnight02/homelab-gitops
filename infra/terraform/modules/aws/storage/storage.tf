# =============================================================================
# AWS Storage Module
# =============================================================================
# Tier-aware storage: S3 buckets, EBS volumes.
# Economy: no S3, minimal EBS (root only).
# Standard: S3 bucket for backups, gp3 EBS.
# Enterprise: S3 versioned + encrypted, gp3 EBS with KMS.
# =============================================================================

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
variable "name_prefix" { type = string }
variable "name_suffix" { type = string }
variable "service_tier" { type = string }
variable "s3_enabled" { type = bool }
variable "s3_versioning" { type = bool }
variable "kms_key_arn" {
  type    = string
  default = null
}
variable "tags" { type = map(string) }

# ---------------------------------------------------------------------------
# S3 Bucket — Backups and Artifacts (Standard+)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "backups" {
  count = var.s3_enabled ? 1 : 0

  bucket = "${var.name_prefix}-backups-${var.name_suffix}"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-backups-${var.name_suffix}"
    Tier = var.service_tier
  })
}

resource "aws_s3_bucket_versioning" "backups" {
  count = var.s3_enabled && var.s3_versioning ? 1 : 0

  bucket = aws_s3_bucket.backups[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  count = var.s3_enabled ? 1 : 0

  bucket = aws_s3_bucket.backups[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null ? true : false
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  count = var.s3_enabled ? 1 : 0

  bucket = aws_s3_bucket.backups[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  count = var.s3_enabled ? 1 : 0

  bucket = aws_s3_bucket.backups[0].id

  rule {
    id     = "backup-lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # Transition to IA after 30 days (standard), Glacier after 90 (enterprise)
    dynamic "transition" {
      for_each = var.service_tier == "enterprise" ? [1] : []
      content {
        days          = 30
        storage_class = "STANDARD_IA"
      }
    }

    dynamic "transition" {
      for_each = var.service_tier == "enterprise" ? [1] : []
      content {
        days          = 90
        storage_class = "GLACIER"
      }
    }

    # Expire old backups
    expiration {
      days = var.service_tier == "enterprise" ? 365 : 30
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "s3_bucket_id" {
  value = var.s3_enabled ? aws_s3_bucket.backups[0].id : null
}

output "s3_bucket_arn" {
  value = var.s3_enabled ? aws_s3_bucket.backups[0].arn : null
}

output "s3_bucket_domain_name" {
  value = var.s3_enabled ? aws_s3_bucket.backups[0].bucket_domain_name : null
}
