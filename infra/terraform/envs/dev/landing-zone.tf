# Chapter 3: the landing zone. Every resource here must pass the guardrails assigned in governance.tf.

data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------- network
resource "azurerm_virtual_network" "dev" {
  name                = "vnet-ztlz-dev"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  address_space       = ["10.20.0.0/16"]
  tags                = local.tags
}

resource "azurerm_network_security_group" "aks" {
  name                = "nsg-ztlz-aks"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  tags                = local.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.dev.name
  virtual_network_name = azurerm_virtual_network.dev.name
  address_prefixes     = ["10.20.0.0/22"]
  # Cluster traffic to Key Vault and Storage stays on the Azure backbone, and their firewalls trust only this subnet
  service_endpoint {
    service = "Microsoft.KeyVault"
  }
  service_endpoint {
    service = "Microsoft.Storage"
  }
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

# ---------------------------------------------------------------- container registry
resource "azurerm_container_registry" "acr" {
  # checkov:skip=CKV_AZURE_164: Content trust is Premium-only; images are pinned by digest and scanned in CI (budget mode, ACR Basic)
  # checkov:skip=CKV_AZURE_165: Geo-replication is Premium-only; single-region dev landing zone
  # checkov:skip=CKV_AZURE_166: Quarantine is Premium-only; CI blocks vulnerable images before they are pushed
  # checkov:skip=CKV_AZURE_167: Retention policy is Premium-only; dev registry is deleted at teardown
  # checkov:skip=CKV_AZURE_233: Zone redundancy is Premium-only; dev landing zone
  # checkov:skip=CKV_AZURE_237: Dedicated data endpoints are Premium-only (budget mode)
  # checkov:skip=CKV_AZURE_139: ACR Basic cannot disable public access; Entra ID is required (admin user off); audited by Azure Policy
  # checkov:skip=CKV_AZURE_163: Images are scanned by Trivy in CI (blocking) and by Defender for Containers
  name                = local.acr_name # the trusted-registry policy already allows only this registry
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  sku                 = "Basic"
  admin_enabled       = false # no shared username/password: push and pull use Entra ID only
  tags                = local.tags
}

# ---------------------------------------------------------------- key vault
resource "azurerm_key_vault" "app" {
  # checkov:skip=CKV2_AZURE_32: Budget mode uses a VNet service endpoint and firewall default Deny instead of a private endpoint
  name                       = "kv-ztlz-dev-${random_string.suffix.result}"
  location                   = azurerm_resource_group.dev.location
  resource_group_name        = azurerm_resource_group.dev.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 7

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [azurerm_subnet.aks.id]
    ip_rules                   = [for ip in local.admin_ips : "${ip}/32"] # my IP only while I work (just in time)
  }

  tags = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

# Lets me write the app's secret in chapter 5; nobody else gets data access
resource "azurerm_role_assignment" "me_kv_secrets_officer" {
  scope                = azurerm_key_vault.app.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ---------------------------------------------------------------- storage (notes table)
resource "azurerm_storage_account" "data" {
  # checkov:skip=CKV_AZURE_59: Service endpoints need the public endpoint; firewall default Deny allows only snet-aks and just-in-time admin IPs
  # checkov:skip=CKV2_AZURE_33: Budget mode uses a VNet service endpoint and firewall default Deny instead of a private endpoint
  # checkov:skip=CKV_AZURE_206: Dev data; LRS is sufficient (no cross-region recovery requirement)
  # checkov:skip=CKV2_AZURE_1: Platform-managed keys plus infrastructure double encryption; customer-managed keys are demonstrated in Project 1
  # checkov:skip=CKV_AZURE_33: The Queue service is not used; the app only uses Tables
  name                              = "stztlzdev${random_string.suffix.result}"
  location                          = azurerm_resource_group.dev.location
  resource_group_name               = azurerm_resource_group.dev.name
  account_kind                      = "StorageV2"
  account_tier                      = "Standard"
  account_replication_type          = "LRS"
  https_traffic_only_enabled        = true
  min_tls_version                   = "TLS1_2"
  shared_access_key_enabled         = false # Entra ID only: no account keys, no SAS signed with keys
  default_to_oauth_authentication   = true
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true

  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [azurerm_subnet.aks.id]
    ip_rules                   = local.admin_ips # storage firewall takes bare IPs, not /32
  }

  tags = local.tags

  lifecycle {
    prevent_destroy = true
  }
}