locals {
  env = "dev"

  # storage account names: lowercase alphanumeric, max 24 chars
  storage_account_name = substr(replace(lower("st${var.prefix}${local.env}"), "-", ""), 0, 24)

  tags = merge(
    {
      course = "terraform-azure"
      owner  = var.owner
    },
    {
      env = local.env
    }
  )
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.prefix}-${local.env}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "this" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # secure defaults
  public_network_access_enabled   = true
  allow_nested_items_to_be_public = false

  tags = local.tags
}
