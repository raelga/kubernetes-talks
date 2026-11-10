terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    key              = "azure/01-vm-basics.tfstate"
    use_azuread_auth = true
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
