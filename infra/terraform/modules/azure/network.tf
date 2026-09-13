# =============================================================================
# Azure Network Module
# =============================================================================
# Reusable module for Azure networking components.
# This is a placeholder for future modularization.
# Currently, network resources are defined inline in the root module.
# =============================================================================

# To use this module, move network resources from main.tf here
# and reference it from the root module:
#
# module "network" {
#   source = "../modules/azure/network"
#
#   resource_group_name = azurerm_resource_group.main.name
#   location            = var.azure_region
#   vnet_name           = local.vnet_name
#   subnet_name         = local.subnet_name
#   nsg_name            = local.nsg_name
#   network_cidr        = var.network_cidr
#   subnet_cidr         = var.subnet_cidr
#   allow_ssh_cidr      = var.allow_ssh_cidr
#   tags                = local.common_tags
# }
