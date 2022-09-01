terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.1"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.2.0"
    }
  }
  required_version = ">= 1.1.3"
}

# Used because the subscription ID of where the Azure Compute Gallery may be different from the target subscription
# where you are deploying the DNS forwarding solution
provider "azurerm" {
  features {}
  alias                      = "image_gallery"
  subscription_id            = var.subscription_id_for_image_gallery
  skip_provider_registration = true
}
