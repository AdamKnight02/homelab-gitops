# =============================================================================
# Alibaba Cloud Secrets Module — Variables
# =============================================================================

variable "name" {
  description = "Name prefix for secrets resources"
  type        = string
}

variable "create_kms_key" {
  description = "Whether to create a KMS key"
  type        = bool
  default     = false
}

variable "kms_key_spec" {
  description = "KMS key specification (Aliyun_AES_256, Aliyun_SM4, RSA_2048, RSA_3072, RSA_4096, EC_SM2, EC_P256, EC_P256K)"
  type        = string
  default     = "Aliyun_AES_256"

  validation {
    condition     = contains(["Aliyun_AES_256", "Aliyun_SM4", "RSA_2048", "RSA_3072", "RSA_4096", "EC_SM2", "EC_P256", "EC_P256K"], var.kms_key_spec)
    error_message = "KMS key spec must be a valid Alibaba Cloud KMS key specification."
  }
}

variable "kms_key_usage" {
  description = "KMS key usage (ENCRYPT/DECRYPT, SIGN/VERIFY)"
  type        = string
  default     = "ENCRYPT/DECRYPT"

  validation {
    condition     = contains(["ENCRYPT/DECRYPT", "SIGN/VERIFY"], var.kms_key_usage)
    error_message = "KMS key usage must be ENCRYPT/DECRYPT or SIGN/VERIFY."
  }
}

variable "create_secret" {
  description = "Whether to create a Secrets Manager secret"
  type        = bool
  default     = false
}

variable "secret_name" {
  description = "Name of the secret"
  type        = string
  default     = ""
}

variable "secret_data" {
  description = "Secret data (sensitive)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "secret_type" {
  description = "Secret type (Generic, Rds, Redis, ECS, RAM)"
  type        = string
  default     = "Generic"

  validation {
    condition     = contains(["Generic", "Rds", "Redis", "ECS", "RAM"], var.secret_type)
    error_message = "Secret type must be one of: Generic, Rds, Redis, ECS, RAM."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
