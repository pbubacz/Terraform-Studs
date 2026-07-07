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
  tags = { course = "terraform-azure", lab = "09" }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.prefix}-hardened"
  location = var.location
  tags     = local.tags
}

# A hardened storage account used to demonstrate policy-as-code.
# The Conftest policy in ../policy/storage.rego asserts each of these controls;
# flip any of them to an insecure value to watch the policy gate fail.
resource "azurerm_storage_account" "hardened" {
  name                = substr(replace(lower("st${var.prefix}hard"), "-", ""), 0, 24)
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  account_tier             = "Standard"
  account_replication_type = "GRS"

  # Hardening controls enforced by policy:
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false

  tags = local.tags
}

output "storage_account_id" {
  value = azurerm_storage_account.hardened.id
}
