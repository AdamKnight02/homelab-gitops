variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "pki-cloudlab"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "homelab"
}

variable "repository_url" {
  description = "URL of the Git repository"
  type        = string
  default     = "https://github.com/AdamKnight02/homelab-gitops"
}
