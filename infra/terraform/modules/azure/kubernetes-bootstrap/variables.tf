# =============================================================================
# Azure Kubernetes Bootstrap Module — Variables
# =============================================================================

variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "instance_count" {
  description = "Number of VM instances"
  type        = number
  default     = 1
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "labadmin"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "k3s_version" {
  description = "K3s release channel or version"
  type        = string
  default     = "v1.30"
}

variable "argocd_version" {
  description = "Argo CD version to install"
  type        = string
  default     = "v2.12"
}

variable "git_repo_url" {
  description = "Git repository URL for Argo CD"
  type        = string
}

variable "git_target_revision" {
  description = "Git branch or tag for Argo CD"
  type        = string
  default     = "main"
}

variable "server_private_ip" {
  description = "Private IP of the first server node (for multi-node)"
  type        = string
  default     = ""
}

variable "k3s_token" {
  description = "K3s cluster token for multi-node join"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_azure_csi" {
  description = "Install Azure Disk/File CSI drivers"
  type        = bool
  default     = false
}

variable "enable_azure_ccm" {
  description = "Install Azure Cloud Controller Manager"
  type        = bool
  default     = false
}

variable "azure_client_id" {
  description = "Azure client ID for cloud provider"
  type        = string
  default     = ""
}

variable "azure_tenant_id" {
  description = "Azure tenant ID"
  type        = string
  default     = ""
}

variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string
  default     = ""
}

variable "azure_resource_group" {
  description = "Azure resource group name"
  type        = string
  default     = ""
}

variable "azure_vnet_name" {
  description = "Azure VNet name"
  type        = string
  default     = ""
}

variable "azure_subnet_name" {
  description = "Azure subnet name"
  type        = string
  default     = ""
}

variable "azure_nsg_name" {
  description = "Azure NSG name"
  type        = string
  default     = ""
}

variable "azure_lb_name" {
  description = "Azure load balancer name"
  type        = string
  default     = ""
}
