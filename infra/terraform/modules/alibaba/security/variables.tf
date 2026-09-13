# =============================================================================
# Alibaba Cloud Security Module — Variables
# =============================================================================

variable "name" {
  description = "Name prefix for security resources"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to create security group in"
  type        = string
}

variable "allow_ssh_cidr" {
  description = "CIDR blocks allowed to SSH to instances"
  type        = list(string)
  default     = []
}

variable "allow_k8s_api_cidr" {
  description = "CIDR blocks allowed to access Kubernetes API (port 6443)"
  type        = list(string)
  default     = []
}

variable "allow_http_cidr" {
  description = "CIDR blocks allowed to access HTTP (port 80)"
  type        = list(string)
  default     = []
}

variable "allow_https_cidr" {
  description = "CIDR blocks allowed to access HTTPS (port 443)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
