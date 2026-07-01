terraform {
  required_version = ">= 1.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "prefix" {
  type    = string
  default = "tfcourse-ab"
}

variable "location" {
  type    = string
  default = "polandcentral"
}

variable "address_space" {
  type    = list(string)
  default = ["10.40.0.0/16"]
}

variable "subnets" {
  type = map(object({
    cidr = string
  }))
  default = {
    web = { cidr = "10.40.1.0/24" }
    db  = { cidr = "10.40.2.0/24" }
  }
}

locals {
  tags = merge(
    { course = "terraform-azure" },
    { layer = "network" }
  )
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.prefix}-net"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.address_space
  tags                = local.tags
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                 = "snet-${each.key}"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value.cidr]
}

output "subnet_ids" {
  description = "Map of subnet name to resource ID."
  value       = { for k, s in azurerm_subnet.this : k => s.id }
}
