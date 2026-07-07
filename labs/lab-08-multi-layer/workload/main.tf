terraform {
  required_version = ">= 1.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  backend "azurerm" {} # supply via -backend-config=backend.hcl (key = workload.tfstate)
}

provider "azurerm" {
  features {}
}

variable "prefix" {
  type    = string
  default = "tfcourse-ab"
}

variable "platform_state_resource_group" {
  type    = string
  default = "rg-tfcourse-ab-tfstate"
}

variable "platform_state_storage_account" {
  type    = string
  default = "sttfcourseabtfstate"
}

variable "platform_state_container" {
  type    = string
  default = "tfstate"
}

variable "platform_state_key" {
  type    = string
  default = "platform.tfstate"
}

locals {
  tags = { course = "terraform-azure", lab = "08", layer = "workload", owner_team = "app" }
}

# Read the platform layer's outputs (one-way dependency: workload -> platform).
data "terraform_remote_state" "platform" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.platform_state_resource_group
    storage_account_name = var.platform_state_storage_account
    container_name       = var.platform_state_container
    key                  = var.platform_state_key
    use_azuread_auth     = true
  }
}

# Look up a platform-owned subnet by name using the remote-state outputs.
data "azurerm_subnet" "workload" {
  name                 = "snet-workload"
  virtual_network_name = data.terraform_remote_state.platform.outputs.vnet_name
  resource_group_name  = data.terraform_remote_state.platform.outputs.resource_group_name
}

resource "azurerm_resource_group" "workload" {
  name     = "rg-${var.prefix}-workload"
  location = data.terraform_remote_state.platform.outputs.location
  tags     = local.tags
}

# Place a NIC into a platform-owned subnet, proving cross-layer consumption.
resource "azurerm_network_interface" "app" {
  name                = "nic-${var.prefix}-app"
  location            = azurerm_resource_group.workload.location
  resource_group_name = azurerm_resource_group.workload.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.workload.id
    private_ip_address_allocation = "Dynamic"
  }
}

output "nic_id" {
  value = azurerm_network_interface.app.id
}
