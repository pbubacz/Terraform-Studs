variable "prefix" {
  type    = string
  default = "tfcourse-ab"
}

variable "location" {
  type    = string
  default = "polandcentral"
}

locals {
  # Storage account names: lowercase, 3–24 chars, letters/digits only.
  sa_suffix = "${replace(var.prefix, "-", "")}07" # e.g. tfcourseab07
}

# ── Unchanged from Lab 06 ────────────────────────────────────────────────
resource "azurerm_resource_group" "this" {
  name     = "rg-${var.prefix}-lab06"
  location = var.location
  tags     = { course = "terraform-azure", lab = "06" }
}

# The DIY storage account you already deployed in Lab 06. It sets only the
# secure flags you remembered to add — this is the comparison baseline.
resource "azurerm_storage_account" "demo" {
  name                            = "sttfcourseablab06" # your Lab 06 name
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = { course = "terraform-azure", lab = "06" }
}

# ── NEW in Lab 07 ────────────────────────────────────────────────────────
# AVM Resource module: Storage Account (AzAPI-based, secure by default).
# You get Azure Policy / WAF-aligned defaults for free: public network access
# disabled, shared key disabled, deny network rules, TLS1_2, no public blobs,
# no cross-tenant replication, etc. Copy inputs/version from the registry.
module "storage" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.7.3"

  name      = "stavm${local.sa_suffix}"
  location  = azurerm_resource_group.this.location
  parent_id = azurerm_resource_group.this.id

  account_sku_name = "Standard_LRS"
  tags             = { course = "terraform-azure", lab = "07" }
  enable_telemetry = true
}

output "diy_storage_name" {
  value = azurerm_storage_account.demo.name
}

output "avm_storage_name" {
  value = module.storage.name
}

output "avm_storage_resource_id" {
  value = module.storage.resource_id
}
