# =============================================================================
# Alibaba Cloud Storage Module — Variables
# =============================================================================

variable "name" {
  description = "Name prefix for storage resources"
  type        = string
}

variable "create_oss_bucket" {
  description = "Whether to create an OSS bucket"
  type        = bool
  default     = false
}

variable "oss_bucket_acl" {
  description = "OSS bucket ACL (private, public-read, public-read-write)"
  type        = string
  default     = "private"

  validation {
    condition     = contains(["private", "public-read", "public-read-write"], var.oss_bucket_acl)
    error_message = "OSS bucket ACL must be one of: private, public-read, public-read-write."
  }
}

variable "oss_versioning" {
  description = "Enable OSS bucket versioning"
  type        = bool
  default     = false
}

variable "oss_encryption" {
  description = "Enable OSS bucket server-side encryption"
  type        = bool
  default     = true
}

variable "create_nas" {
  description = "Whether to create a NAS file system"
  type        = bool
  default     = false
}

variable "nas_vswitch_id" {
  description = "VSwitch ID for NAS mount target (required if create_nas is true)"
  type        = string
  default     = ""
}

variable "nas_protocol" {
  description = "NAS protocol (NFS, SMB)"
  type        = string
  default     = "NFS"

  validation {
    condition     = contains(["NFS", "SMB"], var.nas_protocol)
    error_message = "NAS protocol must be NFS or SMB."
  }
}

variable "nas_storage_type" {
  description = "NAS storage type (Capacity, Performance)"
  type        = string
  default     = "Capacity"

  validation {
    condition     = contains(["Capacity", "Performance"], var.nas_storage_type)
    error_message = "NAS storage type must be Capacity or Performance."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
