terraform {
  required_version = ">= 1.0, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
  }

  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstate828daceb"
    container_name       = "tfstate"
    key                  = "azure.terraform.tfstate"
    use_oidc             = true
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}
