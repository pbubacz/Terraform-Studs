terraform {
  # The AVM storage module is AzAPI-based and requires Terraform >= 1.10.
  required_version = ">= 1.10"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.8"
    }
  }

  # Reuse the Lab 06 remote backend (init with -backend-config=backend.hcl).
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

# AzAPI authenticates with the same ARM_* / OIDC env vars the pipeline exports
# (ARM_USE_OIDC, ARM_CLIENT_ID, ARM_TENANT_ID, ARM_OIDC_TOKEN, ARM_SUBSCRIPTION_ID).
provider "azapi" {}
