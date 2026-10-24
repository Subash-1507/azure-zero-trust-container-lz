# Chapter 4: the AKS cluster, in the landing zone's own subnet (snet-aks), which Key Vault and Storage already trust.

locals {
  admin_ips = var.admin_ip == "" ? [] : [var.admin_ip]
  # Without my IP, only the cluster's own egress IP may reach the API server: the door is closed for humans
  api_ip_ranges = concat(["${azurerm_public_ip.aks_egress.ip_address}/32"], [for ip in local.admin_ips : "${ip}/32"])
}

# One fixed egress IP: predictable outbound address, and the API server's permanent allow-list entry
resource "azurerm_public_ip" "aks_egress" {
  name                = "pip-ztlz-aks-egress"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

# ---------------------------------------------------------------- control-plane identity
resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-ztlz-aks"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  tags                = local.tags
}

# The control plane manages the node subnet and the egress IP, and nothing else
resource "azurerm_role_assignment" "aks_subnet" {
  scope                = azurerm_subnet.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "aks_egress_ip" {
  scope                = azurerm_public_ip.aks_egress.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  principal_type       = "ServicePrincipal"
}

# ---------------------------------------------------------------- Defender logs (capped to protect credits)
resource "azurerm_log_analytics_workspace" "aks" {
  name                = "log-ztlz-dev"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.2
  tags                = local.tags
}

# ---------------------------------------------------------------- the cluster
resource "azurerm_kubernetes_cluster" "aks" {
  # checkov:skip=CKV_AZURE_115: Private cluster needs a jump host or VPN (cost); API server limited to authorized IPs, Entra ID only, local accounts disabled
  # checkov:skip=CKV_AZURE_170: Dev cluster on the Free tier; no uptime SLA required
  # checkov:skip=CKV_AZURE_117: Platform-managed keys plus host encryption; customer-managed keys are demonstrated in Project 1
  # checkov:skip=CKV_AZURE_4: Container Insights omitted for cost; the Defender sensor sends audit logs to the capped Log Analytics workspace
  # checkov:skip=CKV_AZURE_232: Single node pool by design (budget); a separate user pool would double the node cost
  # checkov:skip=CKV_AZURE_226: Bsv2 sizes have no local temp disk, so ephemeral OS disks are not possible
  name                      = "aks-ztlz-dev"
  location                  = azurerm_resource_group.dev.location
  resource_group_name       = azurerm_resource_group.dev.name
  dns_prefix                = "aks-ztlz-dev"
  kubernetes_version        = var.kubernetes_version
  sku_tier                  = "Free"
  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "SecurityPatch"

  # Identity and access: Entra ID only
  local_account_disabled    = true
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  run_command_enabled       = false

  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled = true
  }

  api_server_access_profile {
    authorized_ip_ranges = local.api_ip_ranges
  }

  # Guardrails and secrets
  azure_policy_enabled         = true
  image_cleaner_enabled        = true
  image_cleaner_interval_hours = 48

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  }

  node_provisioning_profile {
    mode = "Manual" # classic, explicitly defined node pools (no Node Auto Provisioning)
  }

  default_node_pool {
    name                        = "system"
    vm_size                     = var.aks_node_size
    node_count                  = 1
    os_sku                      = "AzureLinux"
    os_disk_size_gb             = 64
    host_encryption_enabled     = true # temp disks, caches and host-to-storage traffic encrypted
    max_pods                    = 50
    vnet_subnet_id              = azurerm_subnet.aks.id
    temporary_name_for_rotation = "systemtmp"
    tags                        = local.tags

    upgrade_settings {
      max_surge = "1"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "calico"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"

    load_balancer_profile {
      outbound_ip_address_ids = [azurerm_public_ip.aks_egress.id]
    }
  }

  tags = local.tags

  depends_on = [azurerm_role_assignment.aks_subnet, azurerm_role_assignment.aks_egress_ip]
}

# ---------------------------------------------------------------- who may do what
# Nodes pull images from our registry only, with no pull secrets
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  principal_type       = "ServicePrincipal"
}

# Me: fetch the (Entra-only) kubeconfig, and administer the cluster through Azure RBAC
resource "azurerm_role_assignment" "me_aks_user" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "me_aks_rbac_admin" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}