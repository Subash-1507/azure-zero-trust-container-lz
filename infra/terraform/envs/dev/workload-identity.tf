# Workload identity for the notes API: the pod exchanges its Kubernetes service account token
# for an Entra ID token, so no keys, passwords or connection strings exist anywhere.

locals {
  app_namespace       = "notes"
  api_service_account = "api"
}

resource "azurerm_user_assigned_identity" "api" {
  name                = "id-ztlz-api"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  tags                = local.tags
}

# Trust exactly one subject: the "api" service account in the "notes" namespace of this cluster
resource "azurerm_federated_identity_credential" "api" {
  name                      = "aks-${local.app_namespace}-${local.api_service_account}"
  user_assigned_identity_id = azurerm_user_assigned_identity.api.id
  issuer                    = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  subject                   = "system:serviceaccount:${local.app_namespace}:${local.api_service_account}"
  audience                  = ["api://AzureADTokenExchange"]
}

# Read secrets only; the vault holds nothing but this app's secrets
resource "azurerm_role_assignment" "api_kv_secrets_user" {
  scope                = azurerm_key_vault.app.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# azurerm_storage_table goes through the table data plane, which would force a standing data role on the
# human running Terraform. azapi uses Azure Resource Manager only: Terraform manages the table, never its data.
resource "azapi_resource" "notes_table" {
  type      = "Microsoft.Storage/storageAccounts/tableServices/tables@2023-05-01"
  name      = "notes"
  parent_id = "${azurerm_storage_account.data.id}/tableServices/default"
}

# Scoped to the single table, not the whole storage account
resource "azurerm_role_assignment" "api_table_data" {
  scope                = azapi_resource.notes_table.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}