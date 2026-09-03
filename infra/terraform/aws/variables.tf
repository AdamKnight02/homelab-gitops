# variables.tf — AWS PKI Lab Infrastructure
# Input variables for customizable deployment

# ---------------------------------------------------------------------------
# Project & Environment
# ---------------------------------------------------------------------------

variable "project_name" {
  description = "Project identifier used in resource naming"
  type        = string
  default     = "pki-cloudlab"
}

variable "environment" {
  description = "Environment name (lab, dev, staging, prod)"
  type        = string
  default     = "lab"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.1.1.0/24"
}

variable "availability_zone" {
  description = "AWS Availability Zone"
  type        = string
  default     = "us-east-1a"
}

# ---------------------------------------------------------------------------
# Compute (EC2)
# ---------------------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type. t2.micro is AWS Free Tier eligible."
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI ID for EC2 instance. If empty, latest Ubuntu 22.04 LTS is used."
  type        = string
  default     = ""
}

variable "key_name" {
  description = "Name of AWS EC2 Key Pair. If empty, a new key pair is created."
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Size of root EBS volume in GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Type of root EBS volume (gp2, gp3, io1, io2, sc1, st1, standard)"
  type        = string
  default     = "gp2"
}

# ---------------------------------------------------------------------------
# K3s & GitOps Configuration
# ---------------------------------------------------------------------------

variable "k3s_version" {
  description = "K3s release channel or version"
  type        = string
  default     = "v1.30.3+k3s1"
}

variable "argocd_version" {
  description = "Argo CD version to install"
  type        = string
  default     = "v2.11.4"
}

variable "gitops_repo_url" {
  description = "Git repository URL for Argo CD to sync"
  type        = string
  default     = "https://github.com/AdamKnight02/homelab-gitops.git"
}

variable "gitops_target_revision" {
  description = "Git branch or tag for Argo CD to track"
  type        = string
  default     = "main"
}

variable "gitops_path" {
  description = "Path within the Git repo containing Argo CD apps"
  type        = string
  default     = "apps/overlays/aws"
}

# ---------------------------------------------------------------------------
# Security
# ---------------------------------------------------------------------------

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access. Restrict to your IP for security."
  type        = string
  default     = "0.0.0.0/0"
}

variable "enable_public_ip" {
  description = "Assign a public IP to the EC2 instance"
  type        = bool
  default     = true
}
