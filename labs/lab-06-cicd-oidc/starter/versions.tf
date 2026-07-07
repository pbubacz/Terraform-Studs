terraform {
  required_version = ">= 1.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Backend settings are supplied at init time:
  #   - locally / GitHub: terraform init -backend-config=backend.hcl
  #   - Azure DevOps:     values are passed by the TerraformTask inputs
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}
