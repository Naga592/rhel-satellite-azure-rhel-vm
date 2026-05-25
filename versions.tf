# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }
}

#  backend "azurerm" {
#   resource_group_name  = "tfstate-rg"
#    storage_account_name = "satfstatenew"
#    container_name       = "tfstate"
#    key                  = "terraform.tfstate"
#    use_azuread_auth     = true
#  }
#}
