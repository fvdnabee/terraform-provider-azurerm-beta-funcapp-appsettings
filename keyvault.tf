resource "azurerm_key_vault" "funcapp" {
  name                = "kv-${random_string.suffix.result}"
  tenant_id           = data.azurerm_client_config.current.tenant_id
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku_name            = "standard"

  soft_delete_retention_days = 7

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
    # List of Azure trusted services here:
    # https://docs.microsoft.com/en-us/azure/key-vault/general/overview-vnet-service-endpoints#trusted-services
  }

  tags = {terraform_test="true"}
}

# function app has a dedicated user assigned identity to access its key vault
resource "azurerm_user_assigned_identity" "kv" {
  name                = "id-${random_string.suffix.result}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  tags = {terraform_test="true"}
}

# Access policy to grant the principal creating the key vault access to its
# secrets (this is required in order to set secrets within the vault from
# terraform)
# See https://github.com/hashicorp/terraform-provider-azurerm/issues/4569#issuecomment-611488341
resource "azurerm_key_vault_access_policy" "owner" {
  key_vault_id = azurerm_key_vault.funcapp.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id  # object_id identifies the current principal

  secret_permissions = [
    "Delete",
    "Get",
    "Set",
    "List",
    "Purge",
    "Recover",
    "Restore"
  ]
}

# Access policy to grant our Function App access to the secrets in the AKV:
# Note: requires Function App to have a managed identity
# Secret permissions as per https://docs.microsoft.com/en-us/azure/azure-functions/security-concepts#secret-repositories:
# # The access policy should grant the identity the following secret permissions:
# # Get,Set, List, and Delete.
resource "azurerm_key_vault_access_policy" "funcapp" {
  key_vault_id = azurerm_key_vault.funcapp.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.kv.principal_id

  secret_permissions = [
    "Delete",
    "Get",
    "Set",
    "List"
  ]
}

resource "azurerm_key_vault_secret" "azure_files_connection_string" {
  name         = "azure-files-connection-string"
  key_vault_id = azurerm_key_vault.funcapp.id
  value        = azurerm_storage_account.funcapp.primary_connection_string

  content_type    = "text/plain"

  # We must delay the secret creation until the policy of the vault owner has
  # been created
  depends_on = [azurerm_key_vault_access_policy.owner]
}
