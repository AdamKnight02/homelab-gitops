# =============================================================================
# AWS Identity Module
# =============================================================================
# Tier-aware IAM roles, instance profiles, and policies.
# Economy: minimal — SSM + CloudWatch read-only.
# Standard: adds S3 access, EBS CSI driver permissions.
# Enterprise: adds KMS, Secrets Manager, full CloudWatch, EKS (if enabled).
# =============================================================================

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
variable "name_prefix" { type = string }
variable "name_suffix" { type = string }
variable "service_tier" { type = string }
variable "s3_bucket_arn" {
  type    = string
  default = null
}
variable "kms_key_arn" {
  type    = string
  default = null
}
variable "tags" { type = map(string) }

# ---------------------------------------------------------------------------
# Assume Role Policy
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# ---------------------------------------------------------------------------
# IAM Role
# ---------------------------------------------------------------------------
resource "aws_iam_role" "main" {
  name               = "${var.name_prefix}-role-${var.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-role-${var.name_suffix}"
    Tier = var.service_tier
  })
}

# ---------------------------------------------------------------------------
# Policy Attachments — All Tiers
# ---------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_readonly" {
  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

# ---------------------------------------------------------------------------
# Policy Attachments — Standard+
# ---------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  count = var.service_tier != "economy" ? 1 : 0

  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# ---------------------------------------------------------------------------
# Custom Policy — S3 Access (Standard+)
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "s3_access" {
  count = var.service_tier != "economy" && var.s3_bucket_arn != null ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*",
    ]
  }
}

resource "aws_iam_policy" "s3_access" {
  count = var.service_tier != "economy" && var.s3_bucket_arn != null ? 1 : 0

  name        = "${var.name_prefix}-s3-access-${var.name_suffix}"
  description = "S3 access for PKI platform backups"
  policy      = data.aws_iam_policy_document.s3_access[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  count = var.service_tier != "economy" && var.s3_bucket_arn != null ? 1 : 0

  role       = aws_iam_role.main.name
  policy_arn = aws_iam_policy.s3_access[0].arn
}

# ---------------------------------------------------------------------------
# Custom Policy — KMS Access (Enterprise)
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "kms_access" {
  count = var.service_tier == "enterprise" && var.kms_key_arn != null ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_policy" "kms_access" {
  count = var.service_tier == "enterprise" && var.kms_key_arn != null ? 1 : 0

  name        = "${var.name_prefix}-kms-access-${var.name_suffix}"
  description = "KMS access for encryption at rest"
  policy      = data.aws_iam_policy_document.kms_access[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "kms_access" {
  count = var.service_tier == "enterprise" && var.kms_key_arn != null ? 1 : 0

  role       = aws_iam_role.main.name
  policy_arn = aws_iam_policy.kms_access[0].arn
}

# ---------------------------------------------------------------------------
# Custom Policy — Secrets Manager Access (Enterprise)
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "secrets_manager" {
  count = var.service_tier == "enterprise" ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets",
    ]
    resources = ["arn:aws:secretsmanager:*:*:secret:${var.name_prefix}/*"]
  }
}

resource "aws_iam_policy" "secrets_manager" {
  count = var.service_tier == "enterprise" ? 1 : 0

  name        = "${var.name_prefix}-secrets-manager-${var.name_suffix}"
  description = "Secrets Manager read access for PKI platform"
  policy      = data.aws_iam_policy_document.secrets_manager[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "secrets_manager" {
  count = var.service_tier == "enterprise" ? 1 : 0

  role       = aws_iam_role.main.name
  policy_arn = aws_iam_policy.secrets_manager[0].arn
}

# ---------------------------------------------------------------------------
# Custom Policy — EBS CSI Driver (Standard+)
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ebs_csi" {
  count = var.service_tier != "economy" ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateSnapshot",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
      "ec2:ModifyVolume",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeSnapshots",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:CreateVolume",
      "ec2:DeleteVolume",
      "ec2:DeleteSnapshot",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ebs_csi" {
  count = var.service_tier != "economy" ? 1 : 0

  name        = "${var.name_prefix}-ebs-csi-${var.name_suffix}"
  description = "EBS CSI driver permissions for persistent volumes"
  policy      = data.aws_iam_policy_document.ebs_csi[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count = var.service_tier != "economy" ? 1 : 0

  role       = aws_iam_role.main.name
  policy_arn = aws_iam_policy.ebs_csi[0].arn
}

# ---------------------------------------------------------------------------
# Instance Profile
# ---------------------------------------------------------------------------
resource "aws_iam_instance_profile" "main" {
  name = "${var.name_prefix}-profile-${var.name_suffix}"
  role = aws_iam_role.main.name

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "role_arn" {
  value = aws_iam_role.main.arn
}

output "role_name" {
  value = aws_iam_role.main.name
}

output "instance_profile_name" {
  value = aws_iam_instance_profile.main.name
}

output "instance_profile_arn" {
  value = aws_iam_instance_profile.main.arn
}
