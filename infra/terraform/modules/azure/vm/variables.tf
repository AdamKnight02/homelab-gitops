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
    vm_name  = string
    nic_name = string
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

variable "config" {
  description = "VM configuration object"
  type = object({
    vm_size         = string
    admin_username  = string
    os_disk_size_gb = optional(number, 128)
    image_reference = optional(object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
      }), {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
      version   = "latest"
    })
  })
}
