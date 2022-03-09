terraform {
  required_version = "~> 1.1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.98.0"
    }
  }
}

# data source to access the configuration of the AzureRM provider:
data "azurerm_client_config" "current" {}

# data source for pre-existing resource group:
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

resource "random_string" "suffix" {
  length  = 12
  lower   = true
  number  = true
  upper   = false
  special = false
}
