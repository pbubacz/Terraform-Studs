variable "prefix" {
  type    = string
  default = "tfcourse-ab"
}

variable "location" {
  type    = string
  default = "polandcentral"
}

# A small workload managed by the pipeline.
resource "azurerm_resource_group" "this" {
  name     = "rg-${var.prefix}-lab06"
  location = var.location
  tags     = { course = "terraform-azure", lab = "06" }
}

# Storage account used to demonstrate the shift-left (tfsec) gate.
# Secure baseline — Part 3 flips one attribute to an insecure value to prove
# the pipeline blocks it, then reverts it.
resource "azurerm_storage_account" "demo" {
  name                            = "sttfcourseablab06" # must be GLOBALLY UNIQUE
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false # secure baseline
  tags                            = { course = "terraform-azure", lab = "06" }
}

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "storage_account_name" {
  value = azurerm_storage_account.demo.name
}
