# =============================================================================
# Alibaba Cloud Database Module — Main Resources
# =============================================================================

# ---------------------------------------------------------------------------
# ApsaraDB RDS PostgreSQL Instance
# ---------------------------------------------------------------------------
resource "alicloud_db_instance" "main" {
  count = var.create_rds ? 1 : 0

  engine               = "PostgreSQL"
  engine_version       = var.engine_version
  instance_type        = var.instance_type
  instance_storage     = var.instance_storage
  instance_charge_type = var.instance_charge_type
  instance_name        = "${var.name}-rds"

  zone_id         = var.zone_id != "" ? var.zone_id : null
  zone_id_slave_a = var.ha_enabled && var.zone_id_slave != "" ? var.zone_id_slave : null

  vswitch_id         = var.vswitch_id
  security_group_ids = var.security_group_ids

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------
resource "alicloud_db_database" "main" {
  count = var.create_rds ? 1 : 0

  instance_id    = alicloud_db_instance.main[0].id
  data_base_name = var.database_name
  character_set  = "UTF8"
}

# ---------------------------------------------------------------------------
# Database Account
# ---------------------------------------------------------------------------
resource "alicloud_rds_account" "main" {
  count = var.create_rds ? 1 : 0

  db_instance_id   = alicloud_db_instance.main[0].id
  account_name     = var.account_name
  account_password = var.account_password != "" ? var.account_password : random_password.db[0].result
  account_type     = "Super"
}

resource "random_password" "db" {
  count = var.create_rds && var.account_password == "" ? 1 : 0

  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ---------------------------------------------------------------------------
# Database Account Privilege
# ---------------------------------------------------------------------------
resource "alicloud_db_account_privilege" "main" {
  count = var.create_rds ? 1 : 0

  instance_id  = alicloud_db_instance.main[0].id
  account_name = alicloud_rds_account.main[0].account_name
  db_names     = [alicloud_db_database.main[0].data_base_name]
  privilege    = "DBOwner"
}

# ---------------------------------------------------------------------------
# Connection String (for outputs)
# ---------------------------------------------------------------------------
locals {
  connection_string = var.create_rds ? "postgresql://${alicloud_rds_account.main[0].account_name}:${var.account_password != "" ? var.account_password : random_password.db[0].result}@${alicloud_db_instance.main[0].connection_string}:${alicloud_db_instance.main[0].port}/${alicloud_db_database.main[0].data_base_name}" : null
}
