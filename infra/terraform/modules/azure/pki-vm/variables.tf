variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "naming" {
  description = "Naming convention outputs from shared/naming module"
  type = object({
    vm_name   = string
    nic_name  = string
    disk_name = string
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "subnet_id" {
  description = "Subnet ID for the VM NIC"
  type        = string
}

variable "identity_ids" {
  description = "List of managed identity IDs to assign to the VM"
  type        = list(string)
}

variable "keyvault_id" {
  description = "Key Vault ID for certificate storage"
  type        = string
}

variable "storage_account_name" {
  description = "Storage account name for CRL/backup storage"
  type        = string
}

variable "postgresql_fqdn" {
  description = "PostgreSQL server FQDN for PKI metadata"
  type        = string
}

variable "config" {
  description = "PKI VM configuration object"
  type = object({
    vm_size           = string
    admin_username    = string
    os_disk_size_gb   = optional(number, 128)
    data_disk_size_gb = optional(number, 512)
    enable_backup     = optional(bool, true)
  })
}
