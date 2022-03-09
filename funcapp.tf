resource "azurerm_storage_account" "funcapp" {
  name                = "stfx${random_string.suffix.result}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {terraform_test="true"}
}

resource "azurerm_service_plan" "funcapp" {
  name                = "plan-${random_string.suffix.result}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  sku_name = "Y1"  # Y1: consumption SKU
  os_type  = "Windows"

  tags = {terraform_test="true"}
}

resource "azurerm_windows_function_app" "funcapp" {
  name                = "func-${random_string.suffix.result}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  service_plan_id = azurerm_service_plan.funcapp.id

  storage_account_name          = azurerm_storage_account.funcapp.name
  # We set storage_account_access_key to satisfy the azurerm provider, but we
  # overwrite where it is used via a user defined app setting for
  # AzureWebJobsStorage, which takes precedence over storage_account_access_key
  # according to https://github.com/hashicorp/terraform-provider-azurerm/blob/main/internal/services/appservice/helpers/function_app_schema.go#L2100
  storage_account_access_key = azurerm_storage_account.funcapp.primary_access_key

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.kv.id]
  }

  # Use a user-assigned identity as the storage account connection string
  # resides in a key vault secret
  # https://docs.microsoft.com/en-us/azure/app-service/app-service-key-vault-references#access-vaults-with-a-user-assigned-identity
  # https://docs.microsoft.com/en-us/azure/azure-functions/functions-identity-based-connections-tutorial#create-a-function-app-that-uses-key-vault-for-necessary-secrets
  key_vault_reference_identity_id = azurerm_user_assigned_identity.kv.id

  app_settings = {
    # Overwrite AzureWebJobsStorage which is set from storage_account_access_key
    # with a key vault reference as documented here:
    # https://github.com/hashicorp/terraform-provider-azurerm/blob/main/internal/services/appservice/helpers/function_app_schema.go#L2100
    AzureWebJobsStorage = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.azure_files_connection_string.versionless_id}/${azurerm_key_vault_secret.azure_files_connection_string.version})"

    # Use a key vault reference for the the BuiltinLogging (note: contradicts
    # with builtin_logging_enabled)
    # Required because builtin_logging_enabled=true would add the connection
    # string in plain text as an app setting
    AzureWebJobsDashboard = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.azure_files_connection_string.versionless_id}/${azurerm_key_vault_secret.azure_files_connection_string.version})"

    # Use a key vault reference for accessing Azure Files mount from
    # Windows Consumption plan:
    # Required, otherwise the provider adds the connection string in
    # plain text as an app setting
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.azure_files_connection_string.versionless_id}/${azurerm_key_vault_secret.azure_files_connection_string.version})"
  }
  # Disable BuiltinLogging here, but set AzureWebJobsDashboard as an app
  # setting manually using a Key Vault Reference
  builtin_logging_enabled     = false

  site_config {
    application_stack {
      node_version = "14" # cannot use 16: expected site_config.0.application_stack.0.node_version to be one of [12 14], got 16
    }
  }

  tags = {terraform_test="true"}
}
