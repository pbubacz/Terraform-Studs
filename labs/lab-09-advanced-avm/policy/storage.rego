package main

import rego.v1

# Policy-as-code gate for Terraform plans (OPA / Conftest).
# Fails any storage account that permits public blob/nested-item access or
# leaves shared key auth enabled.
#
# Usage:
#   terraform plan -out=tfplan
#   terraform show -json tfplan > tfplan.json
#   conftest test tfplan.json --policy ../policy

deny contains msg if {
  some rc in input.resource_changes
  rc.type == "azurerm_storage_account"
  rc.change.after.allow_nested_items_to_be_public == true
  msg := sprintf("Storage account '%s' must not allow public nested items.", [rc.address])
}

deny contains msg if {
  some rc in input.resource_changes
  rc.type == "azurerm_storage_account"
  rc.change.after.shared_access_key_enabled == true
  msg := sprintf("Storage account '%s' must disable shared access keys (use Azure AD).", [rc.address])
}

deny contains msg if {
  some rc in input.resource_changes
  rc.type == "azurerm_storage_account"
  rc.change.after.min_tls_version != "TLS1_2"
  msg := sprintf("Storage account '%s' must enforce min TLS 1.2.", [rc.address])
}
