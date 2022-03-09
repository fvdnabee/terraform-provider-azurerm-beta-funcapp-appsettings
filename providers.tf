provider "azurerm" {
  features {
    key_vault {
      # Our principal does not have authorization to perform action
      # 'Microsoft.KeyVault/locations/deletedVaults/purge/action' over a
      # subscription scope
      purge_soft_delete_on_destroy = false
    }
  }

  skip_provider_registration = true
}
