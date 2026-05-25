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

# Input variable for Azure subscription ID
variable "subscription_id" {
  type = string
}

# Input variable for SSH public key
variable "public_key" {
  type = string
}

# Configure Azure provider
provider "azurerm" {
  subscription_id = var.subscription_id

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Create Resource Group
resource "azurerm_resource_group" "Satellite_DR_RG" {
  name     = "satdevarmrgp001"
  location = "West US 2"
}

# Create Virtual Network
resource "azurerm_virtual_network" "Satellite_DR_VNET" {
  name                = "satdevarmvnet001"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.Satellite_DR_RG.location
  resource_group_name = azurerm_resource_group.Satellite_DR_RG.name
}

# Create Subnet inside the Virtual Network
resource "azurerm_subnet" "Satellite_DR_SUBNET" {
  name                 = "satdevarmsnet001"
  resource_group_name  = azurerm_resource_group.Satellite_DR_RG.name
  virtual_network_name = azurerm_virtual_network.Satellite_DR_VNET.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create Network Security Group and allow SSH access on port 22
resource "azurerm_network_security_group" "Satellite_DR_NSG" {
  name                = "satdevarmnsg001"
  location            = azurerm_resource_group.Satellite_DR_RG.location
  resource_group_name = azurerm_resource_group.Satellite_DR_RG.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create Network Interface for the VM
resource "azurerm_network_interface" "Satellite_DR_NIC" {
  name                = "satdevarmnic001"
  location            = azurerm_resource_group.Satellite_DR_RG.location
  resource_group_name = azurerm_resource_group.Satellite_DR_RG.name

# Configure NIC to use the subnet with dynamic private IP
  ip_configuration {
    name                          = "satdevarmipcfg001"
    subnet_id                     = azurerm_subnet.Satellite_DR_SUBNET.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Associate the NSG with the NIC
resource "azurerm_network_interface_security_group_association" "Satellite_DR_NIC_NSG_ASSOC" {
  network_interface_id      = azurerm_network_interface.Satellite_DR_NIC.id
  network_security_group_id = azurerm_network_security_group.Satellite_DR_NSG.id
}

# Create Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "Satellite_DR_VM" {
  name                = "satdevarmvm001"
  resource_group_name = azurerm_resource_group.Satellite_DR_RG.name
  location            = azurerm_resource_group.Satellite_DR_RG.location
  size                = "Standard_F2"
  admin_username      = "adminuser"

# Attach NIC to the VM
network_interface_ids = [
    azurerm_network_interface.Satellite_DR_NIC.id,
  ]

# Disable password login and use SSH key instead
  disable_password_authentication = true

# Configure SSH public key for admin user
  admin_ssh_key {
    username   = "adminuser"
    public_key = var.public_key
  }

# Configure OS disk
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

# Use Red Hat Enterprise Linux 9 image
  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "9-lvm"
    version   = "latest"
  }
}

# Create a new empty managed disk of 10 GB
resource "azurerm_managed_disk" "Satellite_DR_DataDisk_01" {
  name                 = "satdevarmdatadisk001"
  location             = azurerm_resource_group.Satellite_DR_RG.location
  resource_group_name  = azurerm_resource_group.Satellite_DR_RG.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
}

# Attach the 10 GB managed disk to the Linux VM
resource "azurerm_virtual_machine_data_disk_attachment" "Satellite_DR_DataDisk_01_Attach" {
  managed_disk_id    = azurerm_managed_disk.Satellite_DR_DataDisk_01.id
  virtual_machine_id = azurerm_linux_virtual_machine.Satellite_DR_VM.id
  lun                = 0
  caching            = "ReadWrite"
}

