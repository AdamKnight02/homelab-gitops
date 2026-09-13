# =============================================================================
# Alibaba Cloud Database Module — Variables
# =============================================================================

variable "name" {
  description = "Name prefix for database resources"
  type        = string
}

variable "create_rds" {
  description = "Whether to create an ApsaraDB RDS PostgreSQL instance"
  type        = bool
  default     = false
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.0"
}

variable "instance_type" {
  description = "RDS instance type (e.g., pg.n2.medium.2c)"
  type        = string
  default     = "pg.n2.medium.2c"
}

variable "instance_storage" {
  description = "RDS instance storage in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.instance_storage >= 20 && var.instance_storage <= 3000
    error_message = "Instance storage must be between 20 and 3000 GB."
  }
}

variable "instance_charge_type" {
  description = "Instance charge type (Postpaid, Prepaid)"
  type        = string
  default     = "Postpaid"

  validation {
    condition     = contains(["Postpaid", "Prepaid"], var.instance_charge_type)
    error_message = "Instance charge type must be Postpaid or Prepaid."
  }
}

variable "zone_id" {
  description = "Primary zone ID for RDS instance"
  type        = string
  default     = ""
}

variable "zone_id_slave" {
  description = "Standby zone ID for HA RDS instance"
  type        = string
  default     = ""
}

variable "vswitch_id" {
  description = "VSwitch ID for RDS instance"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs for RDS"
  type        = list(string)
  default     = []
}

variable "database_name" {
  description = "Name of the default database"
  type        = string
  default     = "pki"
}

variable "account_name" {
  description = "Name of the database account"
  type        = string
  default     = "pkiadmin"
}

variable "account_password" {
  description = "Password for the database account (sensitive)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ha_enabled" {
  description = "Enable high availability (multi-zone)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
