# Naming Module
# Provides consistent naming conventions across environments

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Resource names
  names = {
    resource_group   = "${local.name_prefix}-rg"
    vnet             = "${local.name_prefix}-vnet"
    subnet           = "${local.name_prefix}-subnet"
    nsg              = "${local.name_prefix}-nsg"
    vm               = "${local.name_prefix}-vm"
    disk             = "${local.name_prefix}-disk"
    public_ip        = "${local.name_prefix}-ip"
    nic              = "${local.name_prefix}-nic"
    vpc              = "${local.name_prefix}-vpc"
    igw              = "${local.name_prefix}-igw"
    route_table      = "${local.name_prefix}-rt"
    security_group   = "${local.name_prefix}-sg"
    ec2              = "${local.name_prefix}-ec2"
    ebs              = "${local.name_prefix}-ebs"
    iam_role         = "${local.name_prefix}-role"
    instance_profile = "${local.name_prefix}-profile"
  }
}

output "name_prefix" {
  description = "Prefix for all resource names"
  value       = local.name_prefix
}

output "names" {
  description = "Map of resource names"
  value       = local.names
}
