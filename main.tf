# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }
}

variable "subscription_id" {
  type = string
}

variable "public_key" {
  type = string
}

provider "azurerm" {
  subscription_id = var.subscription_id

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "azurerm_resource_group" "Satellite_DR_RG" {
  name     = "satdevarmrgp001"
  location = "West US 2"
}

resource "azurerm_virtual_network" "Satellite_DR_VNET" {
  name                = "satdevarmvnet001"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.Satellite_DR_RG.location
  resource_group_name = azurerm_resource_group.Satellite_DR_RG.name
}

resource "azurerm_subnet" "Satellite_DR_SUBNET" {
  name                 = "satdevarmsnet001"
  resource_group_name  = azurerm_resource_group.Satellite_DR_RG.name
  virtual_network_name = azurerm_virtual_network.Satellite_DR_VNET.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "Satellite_DR_NIC" {
  name                = "satdevarmnic001"
  location            = azurerm_resource_group.Satellite_DR_RG.location
  resource_group_name = azurerm_resource_group.Satellite_DR_RG.name

  ip_configuration {
    name                          = "satdevarmipcfg001"
    subnet_id                     = azurerm_subnet.Satellite_DR_SUBNET.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "Satellite_DR_VM" {
  name                = "satdevarmvm001"
  resource_group_name = azurerm_resource_group.Satellite_DR_RG.name
  location            = azurerm_resource_group.Satellite_DR_RG.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.Satellite_DR_NIC.id,
  ]

#  admin_ssh_key {
#   username   = "adminuser"
#    public_key = file("~/.ssh/id_rsa.pub")
#  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "9-lvm"
    version   = "latest"
  }
}
