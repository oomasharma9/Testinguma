terraform {
  backend "azurerm" {
    resource_group_name = "rg-secops-spoke-prod-frc-001"
    #what are the values?
    storage_account_name = ""
    container_name       = ""
    key                  = ""
  }
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      #Please confirm the version
      version = "2.68.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "2.2.0"
    }
  }
}

provider "azurerm" {
  features {}
}