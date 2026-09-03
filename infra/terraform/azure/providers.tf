terraform {
  required_version = ">= 1.0, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
  }

  # Local state for lab environment
  # For production, use remote backend:
  # backend "azurerm" {
  #   resource_group_name  = "terraform-state"
  #   storage_account_name = "tfstatepki"
  #   container_name       = "tfstate"
  #   key                  = "azure.terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}
