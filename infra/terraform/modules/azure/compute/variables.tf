# =============================================================================
# Azure Compute Module — Variables
# =============================================================================

variable "name" {
  description = "Name prefix for compute resources"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "instance_count" {
  description = "Number of VM instances to create"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "os_image" {
  description = "OS image for the VMs"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

variable "admin_username" {
  description = "Admin username for the VMs"
  type        = string
  default     = "labadmin"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for VM network interfaces"
  type        = string
}

variable "enable_public_ip" {
  description = "Whether to allocate public IPs for VMs"
  type        = bool
  default     = false
}

variable "availability_zones" {
  description = "Number of availability zones (0 = no zones)"
  type        = number
  default     = 0

  validation {
    condition     = var.availability_zones >= 0 && var.availability_zones <= 3
    error_message = "Availability zones must be 0-3."
  }
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 30
}

variable "os_disk_type" {
  description = "OS disk storage type"
  type        = string
  default     = "StandardSSD_LRS"
}

variable "enable_data_disks" {
  description = "Whether to attach data disks to VMs"
  type        = bool
  default     = false
}

variable "data_disk_size_gb" {
  description = "Data disk size in GB"
  type        = number
  default     = 50
}

variable "data_disk_type" {
  description = "Data disk storage type"
  type        = string
  default     = "PremiumSSD_LRS"
}

variable "managed_identity_id" {
  description = "ID of the user-assigned managed identity (empty to skip)"
  type        = string
  default     = ""
}

variable "cloud_init_configs" {
  description = "List of cloud-init configurations (one per instance)"
  type        = list(string)
}

variable "use_static_private_ips" {
  description = "Use static private IPs (predictable, for K3s server URL)"
  type        = bool
  default     = false
}

variable "subnet_cidr" {
  description = "Subnet CIDR block (needed for static IP calculation)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
