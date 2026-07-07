terraform {
  required_version = ">= 1.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  backend "azurerm" {} # supply via -backend-config=backend.hcl (key = platform.tfstate)
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
  tags = { course = "terraform-azure", lab = "08", layer = "platform", owner_team = "platform" }
}

resource "azurerm_resource_group" "platform" {
  name     = "rg-${var.prefix}-platform"
  location = var.location
  tags     = local.tags
}

# Hub network via AVM Resource module (the platform team owns this).
module "hub" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.19.0"

  name          = "vnet-${var.prefix}-hub"
  location      = azurerm_resource_group.platform.location
  parent_id     = azurerm_resource_group.platform.id
  address_space = ["10.100.0.0/16"]

  subnets = {
    workload = {
      name             = "snet-workload"
      address_prefixes = ["10.100.1.0/24"]
    }
    shared = {
      name             = "snet-shared"
      address_prefixes = ["10.100.2.0/24"]
    }
  }

  tags             = local.tags
  enable_telemetry = true
}

# Public output contract consumed by workload layers.
# We expose stable identifiers (names) so workloads can look up subnets via a
# data source, decoupling them from the platform module's internal output shape.
output "location" {
  value = azurerm_resource_group.platform.location
}

output "resource_group_name" {
  value = azurerm_resource_group.platform.name
}

output "vnet_id" {
  value = module.hub.resource_id
}

output "vnet_name" {
  value = module.hub.name
}

output "subnet_names" {
  value = keys(module.hub.subnets)
}
