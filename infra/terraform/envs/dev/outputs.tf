output "resource_group" {
  description = "Resource group that holds the workload and carries the policy assignment."
  value       = azurerm_resource_group.dev.name
}

output "acr_name" {
  description = "Planned Container Registry name; the trusted-registry policy already allows only this registry."
  value       = local.acr_name
}

output "policy_assignment_id" {
  description = "Zero-trust initiative assignment."
  value       = azurerm_resource_group_policy_assignment.zero_trust.id
}

output "acr_login_server" {
  description = "Registry the cluster will pull from."
  value       = azurerm_container_registry.acr.login_server
}

output "key_vault_name" {
  description = "Key Vault for the app's secrets."
  value       = azurerm_key_vault.app.name
}

output "storage_account_name" {
  description = "Storage account for the notes table."
  value       = azurerm_storage_account.data.name
}

output "aks_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_egress_ip" {
  description = "The cluster's only outbound IP (also its permanent API server allow-list entry)."
  value       = azurerm_public_ip.aks_egress.ip_address
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer used by workload identity federation."
  value       = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

output "api_identity_client_id" {
  description = "Client ID the api service account and the SecretProviderClass use for workload identity (not a secret)."
  value       = azurerm_user_assigned_identity.api.client_id
}

output "tenant_id" {
  description = "Entra tenant for the SecretProviderClass (not a secret, but kept out of the repo)."
  value       = data.azurerm_client_config.current.tenant_id
}
