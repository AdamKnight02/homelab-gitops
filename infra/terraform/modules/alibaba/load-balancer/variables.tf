# =============================================================================
# Alibaba Cloud Load Balancer Module — Variables
# =============================================================================

variable "name" {
  description = "Name prefix for load balancer resources"
  type        = string
}

variable "create_slb" {
  description = "Whether to create a Server Load Balancer (SLB)"
  type        = bool
  default     = false
}

variable "slb_type" {
  description = "SLB type (slb, nlb)"
  type        = string
  default     = "slb"

  validation {
    condition     = contains(["slb", "nlb"], var.slb_type)
    error_message = "SLB type must be slb or nlb."
  }
}

variable "slb_spec" {
  description = "SLB specification (slb.s1.small, slb.s2.small, slb.s2.medium, slb.s3.small, slb.s3.medium, slb.s3.large)"
  type        = string
  default     = "slb.s1.small"
}

variable "address_type" {
  description = "Address type (internet, intranet)"
  type        = string
  default     = "intranet"

  validation {
    condition     = contains(["internet", "intranet"], var.address_type)
    error_message = "Address type must be internet or intranet."
  }
}

variable "vswitch_id" {
  description = "VSwitch ID for SLB placement"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for NLB placement"
  type        = string
  default     = ""
}

variable "master_zone_id" {
  description = "Master zone ID for SLB"
  type        = string
  default     = ""
}

variable "slave_zone_id" {
  description = "Slave zone ID for SLB (for HA)"
  type        = string
  default     = ""
}

variable "backend_servers" {
  description = "List of backend server IDs"
  type        = list(string)
  default     = []
}

variable "listener_ports" {
  description = "Map of listener ports to backend ports"
  type = map(object({
    frontend_port = number
    backend_port  = number
    protocol      = string
  }))
  default = {
    http = {
      frontend_port = 80
      backend_port  = 80
      protocol      = "tcp"
    }
    https = {
      frontend_port = 443
      backend_port  = 443
      protocol      = "tcp"
    }
  }
}

variable "health_check" {
  description = "Health check configuration"
  type = object({
    enabled             = bool
    check_type          = string
    check_port          = number
    check_interval      = number
    check_timeout       = number
    healthy_threshold   = number
    unhealthy_threshold = number
  })
  default = {
    enabled             = true
    check_type          = "tcp"
    check_port          = 6443
    check_interval      = 2
    check_timeout       = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
