# =============================================================================
# Alibaba Cloud Kubernetes Bootstrap Module — Variables
# =============================================================================

variable "name" {
  description = "Name prefix for bootstrap resources"
  type        = string
}

variable "k3s_version" {
  description = "K3s release channel or version to install"
  type        = string
  default     = "v1.30"
}

variable "argocd_version" {
  description = "Argo CD version to install"
  type        = string
  default     = "v2.12"
}

variable "git_repo_url" {
  description = "Git repository URL for Argo CD to sync"
  type        = string
  default     = "https://github.com/AdamKnight02/homelab-gitops.git"
}

variable "git_target_revision" {
  description = "Git branch or tag for Argo CD to track"
  type        = string
  default     = "main"
}

variable "admin_username" {
  description = "Admin username for instances"
  type        = string
  default     = "root"
}

variable "ssh_public_key" {
  description = "SSH public key for access"
  type        = string
  default     = ""
}

variable "hostname" {
  description = "Hostname for the instance"
  type        = string
  default     = "k3s-node"
}

variable "server_url" {
  description = "K3s server URL for agent nodes (empty for server)"
  type        = string
  default     = ""
}

variable "token" {
  description = "K3s cluster token (sensitive)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "is_server" {
  description = "Whether this is a K3s server node"
  type        = bool
  default     = true
}

variable "disable_traefik" {
  description = "Disable Traefik ingress controller"
  type        = bool
  default     = true
}

variable "disable_servicelb" {
  description = "Disable ServiceLB (Klipper LB)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
