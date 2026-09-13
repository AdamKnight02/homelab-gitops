# =============================================================================
# Alibaba Cloud Storage Module — Main Resources
# =============================================================================

# ---------------------------------------------------------------------------
# OSS Bucket
# ---------------------------------------------------------------------------
resource "alicloud_oss_bucket" "main" {
  count = var.create_oss_bucket ? 1 : 0

  bucket = "${var.name}-oss"

  versioning {
    status = var.oss_versioning ? "Enabled" : "Suspended"
  }

  server_side_encryption_rule {
    sse_algorithm = var.oss_encryption ? "AES256" : null
  }

  tags = var.tags
}

resource "alicloud_oss_bucket_acl" "main" {
  count = var.create_oss_bucket ? 1 : 0

  bucket = alicloud_oss_bucket.main[0].bucket
  acl    = var.oss_bucket_acl
}

# ---------------------------------------------------------------------------
# OSS Bucket Lifecycle Rule (optional — for cost control)
# Note: alicloud_oss_bucket_lifecycle is not available in the current provider version
# Lifecycle rules can be configured via the Alibaba Cloud Console or CLI
# ---------------------------------------------------------------------------
# resource "alicloud_oss_bucket_lifecycle" "main" {
#   count = var.create_oss_bucket ? 1 : 0
#
#   bucket = alicloud_oss_bucket.main[0].bucket
#
#   rule {
#     id      = "archive-old-objects"
#     enabled = true
#     prefix  = "archive/"
#
#     transitions {
#       days          = 30
#       storage_class = "IA"
#     }
#
#     transitions {
#       days          = 90
#       storage_class = "Archive"
#     }
#
#     expiration {
#       days = 365
#     }
#   }
# }

# ---------------------------------------------------------------------------
# NAS File System (optional)
# ---------------------------------------------------------------------------
resource "alicloud_nas_file_system" "main" {
  count = var.create_nas ? 1 : 0

  protocol_type = var.nas_protocol
  storage_type  = var.nas_storage_type
  description   = "${var.name} NAS file system"
  tags          = var.tags
}

# ---------------------------------------------------------------------------
# NAS Mount Target
# ---------------------------------------------------------------------------
resource "alicloud_nas_mount_target" "main" {
  count = var.create_nas ? 1 : 0

  file_system_id    = alicloud_nas_file_system.main[0].id
  access_group_name = "DEFAULT_VPC_GROUP_NAME"
  vswitch_id        = var.nas_vswitch_id
}
