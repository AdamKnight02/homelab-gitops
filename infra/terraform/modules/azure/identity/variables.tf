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
    identity_names = map(string)
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "config" {
  description = "Identity configuration object"
  type = object({
    identities = map(object({
      role_assignments = optional(list(object({
        scope = string
        role  = string
      })), [])
    }))
  })
}
