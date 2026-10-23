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
