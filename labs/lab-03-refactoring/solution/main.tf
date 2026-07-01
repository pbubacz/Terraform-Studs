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

variable "subscription_id" {
  type        = string
  description = "Target subscription ID for the import block resource ID."
}

# Final state after Part A (import) and Part B (rename with moved).
resource "azurerm_resource_group" "platform_rg" {
  name     = "rg-tfcourse-ab-legacy"
  location = "polandcentral"
  tags     = { course = "terraform-azure", adopted = "true" }
}

import {
  to = azurerm_resource_group.platform_rg
  id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-tfcourse-ab-legacy"
}

# Part B: the block was originally named "legacy"; this records the rename so
# Terraform updates state instead of destroying + recreating.
moved {
  from = azurerm_resource_group.legacy
  to   = azurerm_resource_group.platform_rg
}
