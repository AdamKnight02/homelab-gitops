# =============================================================================
# Alibaba Cloud Compute Module — Variables
# =============================================================================

variable "name" {
  description = "Name prefix for compute resources"
  type        = string
}

variable "instance_count" {
  description = "Number of ECS instances to create"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

variable "instance_type" {
  description = "ECS instance type (e.g., ecs.t6-c1m2.large)"
  type        = string
  default     = "ecs.t6-c1m2.large"
}

variable "image_id" {
  description = "Image ID for ECS instances. If empty, uses latest Ubuntu 22.04."
  type        = string
  default     = ""
}

variable "system_disk_category" {
  description = "System disk category (cloud_efficiency, cloud_ssd, cloud_essd)"
  type        = string
  default     = "cloud_efficiency"

  validation {
    condition     = contains(["cloud_efficiency", "cloud_ssd", "cloud_essd"], var.system_disk_category)
    error_message = "System disk category must be one of: cloud_efficiency, cloud_ssd, cloud_essd."
  }
}

variable "system_disk_size" {
  description = "System disk size in GB"
  type        = number
  default     = 30

  validation {
    condition     = var.system_disk_size >= 20 && var.system_disk_size <= 500
    error_message = "System disk size must be between 20 and 500 GB."
  }
}

variable "data_disks" {
  description = "List of data disks to attach"
  type = list(object({
    category = string
    size     = number
    name     = string
  }))
  default = []
}

variable "vswitch_id" {
  description = "VSwitch ID for instance placement"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
  default     = []
}

variable "ram_role_name" {
  description = "RAM role name to attach to instances"
  type        = string
  default     = null
}

variable "key_name" {
  description = "SSH key pair name. If empty, a new key pair is generated."
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key for access. If empty, a new key pair is generated."
  type        = string
  default     = ""
}

variable "admin_username" {
  description = "Admin username for instances"
  type        = string
  default     = "root"
}

variable "user_data" {
  description = "Cloud-init user data script"
  type        = string
  default     = ""
}

variable "internet_max_bandwidth_out" {
  description = "Maximum outbound bandwidth in Mbps (0 = no public IP)"
  type        = number
  default     = 0

  validation {
    condition     = var.internet_max_bandwidth_out >= 0 && var.internet_max_bandwidth_out <= 100
    error_message = "Bandwidth must be between 0 and 100 Mbps."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
