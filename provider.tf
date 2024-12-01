terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.9.0"
    }
  }
}

provider "azurerm" {
  subscription_id = "c8b5952b-4423-47c5-8a8c-faaf44323024"
  features {

  }
}