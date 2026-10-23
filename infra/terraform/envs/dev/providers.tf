provider "azurerm" {
  features {
    key_vault {
      # Purge protection forbids purging: deleted vaults stay soft-deleted and are purged by Azure after retention
      purge_soft_delete_on_destroy = false
    }
  }

  # The provider talks to Blob storage with Entra ID, never with account keys
  storage_use_azuread = true
}
