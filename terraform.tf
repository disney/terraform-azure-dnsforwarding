terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.94"
    }
  }
  required_version = ">= 1.1.3"
}

provider "azurerm" {
  features {}
  alias                      = "image_gallery"
  subscription_id            = "c7e0617f-553f-4b8a-bf10-1a917a4aa9f4"
  tenant_id                  = "56b731a8-a2ac-4c32-bf6b-616810e913c6"
  skip_provider_registration = true
}