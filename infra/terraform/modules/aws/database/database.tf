# =============================================================================
# AWS Database Module
# =============================================================================
# Tier-aware RDS PostgreSQL.
# Economy: no RDS (PostgreSQL runs in container on K3s node).
# Standard: RDS single-AZ db.t3.micro.
# Enterprise: RDS Multi-AZ db.r6g.large with enhanced monitoring.
# =============================================================================

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
variable "name_prefix" { type = string }
variable "name_suffix" { type = string }
variable "service_tier" { type = string }
variable "database_mode" { type = string } # "container", "rds", "rds-multi-az"
variable "instance_class" {
  type    = string
  default = null
}
variable "subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "availability_zones" { type = list(string) }
variable "kms_key_arn" {
  type    = string
  default = null
}
variable "tags" { type = map(string) }

# Database credentials — generated, never hardcoded
variable "db_name" {
  type    = string
  default = "pki"
}
variable "db_username" {
  type    = string
  default = "pkiadmin"
}

# ---------------------------------------------------------------------------
# Random Password for RDS
# ---------------------------------------------------------------------------
resource "random_password" "db" {
  count = var.database_mode != "container" ? 1 : 0

  length  = 32
  special = false # Avoid characters that cause issues in connection strings
}

# ---------------------------------------------------------------------------
# DB Subnet Group
# ---------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  count = var.database_mode != "container" ? 1 : 0

  name       = "${var.name_prefix}-db-subnet-${var.name_suffix}"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-subnet-${var.name_suffix}"
  })
}

# ---------------------------------------------------------------------------
# DB Parameter Group
# ---------------------------------------------------------------------------
resource "aws_db_parameter_group" "main" {
  count = var.database_mode != "container" ? 1 : 0

  name   = "${var.name_prefix}-pg-${var.name_suffix}"
  family = "postgres16"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_statement"
    value = var.service_tier == "enterprise" ? "all" : "ddl"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# RDS Instance
# ---------------------------------------------------------------------------
resource "aws_db_instance" "main" {
  count = var.database_mode != "container" ? 1 : 0

  identifier = "${var.name_prefix}-pg-${var.name_suffix}"

  # Engine
  engine                = "postgres"
  engine_version        = "16.4"
  instance_class        = var.instance_class
  allocated_storage     = var.service_tier == "enterprise" ? 100 : 20
  max_allocated_storage = var.service_tier == "enterprise" ? 500 : 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  # Database
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db[0].result

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = false
  availability_zone      = var.database_mode == "rds" ? var.availability_zones[0] : null
  multi_az               = var.database_mode == "rds-multi-az" ? true : false

  # Parameters
  parameter_group_name = aws_db_parameter_group.main[0].name

  # Backup
  backup_retention_period  = var.service_tier == "enterprise" ? 30 : 7
  backup_window            = "03:00-04:00"
  maintenance_window       = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot    = true
  delete_automated_backups = var.service_tier == "enterprise" ? false : true

  # Monitoring
  performance_insights_enabled    = var.service_tier == "enterprise" ? true : false
  monitoring_interval             = var.service_tier == "enterprise" ? 60 : 0
  enabled_cloudwatch_logs_exports = var.service_tier == "enterprise" ? ["postgresql", "upgrade"] : []

  # Protection
  deletion_protection       = var.service_tier == "enterprise" ? true : false
  skip_final_snapshot       = var.service_tier == "enterprise" ? false : true
  final_snapshot_identifier = var.service_tier == "enterprise" ? "${var.name_prefix}-pg-final-${var.name_suffix}" : null

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-pg-${var.name_suffix}"
    Tier = var.service_tier
  })
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "db_instance_id" {
  value = var.database_mode != "container" ? aws_db_instance.main[0].id : null
}

output "db_endpoint" {
  value = var.database_mode != "container" ? aws_db_instance.main[0].endpoint : null
}

output "db_address" {
  value = var.database_mode != "container" ? aws_db_instance.main[0].address : null
}

output "db_port" {
  value = var.database_mode != "container" ? aws_db_instance.main[0].port : null
}

output "db_name" {
  value = var.database_mode != "container" ? aws_db_instance.main[0].db_name : null
}

output "db_username" {
  value = var.database_mode != "container" ? var.db_username : null
}

output "db_password" {
  value     = var.database_mode != "container" ? random_password.db[0].result : null
  sensitive = true
}

output "db_connection_string" {
  value     = var.database_mode != "container" ? "postgresql://${var.db_username}:${random_password.db[0].result}@${aws_db_instance.main[0].endpoint}/${var.db_name}" : null
  sensitive = true
}
