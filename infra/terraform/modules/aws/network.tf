# =============================================================================
# AWS Network Module
# =============================================================================
# Reusable module for AWS networking components.
# This is a placeholder for future modularization.
# Currently, network resources are defined inline in the root module.
# =============================================================================

# To use this module, move network resources from main.tf here
# and reference it from the root module:
#
# module "network" {
#   source = "../modules/aws/network"
#
#   name_prefix      = local.name_prefix
#   name_suffix      = local.name_suffix
#   vpc_cidr         = var.aws_vpc_cidr
#   subnet_cidr      = var.aws_subnet_cidr
#   availability_zone = coalesce(var.aws_availability_zone, data.aws_availability_zones.available.names[0])
#   allow_ssh_cidr   = var.allow_ssh_cidr
#   associate_public_ip = var.aws_associate_public_ip
#   tags             = local.common_tags
# }
