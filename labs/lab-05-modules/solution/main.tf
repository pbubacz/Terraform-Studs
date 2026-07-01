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

locals {
  tags = { course = "terraform-azure", lab = "05" }
}

resource "azurerm_resource_group" "dev" {
  name     = "rg-${var.prefix}-dev"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "test" {
  name     = "rg-${var.prefix}-test"
  location = var.location
  tags     = local.tags
}

module "net_dev" {
  source = "../modules/network"

  prefix              = "${var.prefix}-dev"
  location            = var.location
  resource_group_name = azurerm_resource_group.dev.name
  address_space       = ["10.10.0.0/16"]
  subnets = {
    web = "10.10.1.0/24"
    db  = "10.10.2.0/24"
  }
  tags = local.tags
}

module "net_test" {
  source = "../modules/network"

  prefix              = "${var.prefix}-test"
  location            = var.location
  resource_group_name = azurerm_resource_group.test.name
  address_space       = ["10.20.0.0/16"]
  subnets = {
    web = "10.20.1.0/24"
  }
  tags = local.tags
}

output "dev_subnet_ids" {
  value = module.net_dev.subnet_ids
}

output "test_subnet_ids" {
  value = module.net_test.subnet_ids
}
