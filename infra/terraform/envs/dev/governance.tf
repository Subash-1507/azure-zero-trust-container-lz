# Guardrails first: the initiative is assigned to the resource group before any workload resource exists.
# Built-in policy IDs were looked up in this subscription (Microsoft renames policies over time).

locals {
  acr_name            = "acrztlzdev${random_string.suffix.result}"
  allowed_image_regex = "^${local.acr_name}\\.azurecr\\.io/.+$"
  tag_policy          = jsondecode(file("${path.module}/../../../../policies/definitions/require-governance-tags.json"))
  builtin             = "/providers/Microsoft.Authorization/policyDefinitions"

  deny  = { effect = { value = "Deny" } }
  audit = { effect = { value = "Audit" } }

  initiative_members = {
    "require-governance-tags" = { id = azurerm_policy_definition.require_tags.id, params = local.deny }

    # Kubernetes (enforced by the Azure Policy add-on / Gatekeeper once AKS exists)
    "no-privileged-containers" = { id = "${local.builtin}/95edb821-ddaf-4404-9732-666045e056b4", params = local.deny }
    "no-privilege-escalation"  = { id = "${local.builtin}/1c6e92c9-99f0-4e55-9cf2-0c234dc48f99", params = local.deny }
    "read-only-root-fs"        = { id = "${local.builtin}/df49d893-a74c-421d-bc95-c663042e5b80", params = local.deny }
    "trusted-registry-only" = {
      id     = "${local.builtin}/febd0533-8e55-448f-b837-bd0e06f16469"
      params = merge(local.deny, { allowedContainerImagesRegex = { value = local.allowed_image_regex } })
    }
    "non-root-users" = {
      id = "${local.builtin}/f06ddb64-5fa3-4b77-b166-acb36f7f6042"
      params = merge(local.deny, {
        runAsUserRule            = { value = "MustRunAsNonRoot" }
        runAsUserRanges          = { value = { ranges = [] } }
        runAsGroupRule           = { value = "RunAsAny" }
        runAsGroupRanges         = { value = { ranges = [] } }
        supplementalGroupsRule   = { value = "RunAsAny" }
        supplementalGroupsRanges = { value = { ranges = [] } }
        fsGroupRule              = { value = "RunAsAny" }
        fsGroupRanges            = { value = { ranges = [] } }
      })
    }

    # Secrets and registry
    "key-vault-firewall" = { id = "${local.builtin}/55615ac9-af46-4a59-874e-391cc3dfb490", params = local.deny }
    # Audit only: budget mode uses ACR Basic, which cannot disable public access or use Private Link (accepted risk)
    "acr-public-access-disabled"    = { id = "${local.builtin}/0fdf0491-d080-4575-b627-ad0e843cba0f", params = local.audit }
    "acr-sku-supports-private-link" = { id = "${local.builtin}/bd560fc0-3c69-498a-ae9f-aa8eb7de0e13", params = local.audit }
    "acr-uses-private-link"         = { id = "${local.builtin}/e8eef0a8-67cf-4eb4-9386-14b0e78733d4", params = local.audit }
  }
}

resource "azurerm_policy_definition" "require_tags" {
  name         = "ztlz-require-governance-tags"
  policy_type  = "Custom"
  mode         = local.tag_policy.properties.mode
  display_name = local.tag_policy.properties.displayName
  description  = local.tag_policy.properties.description
  metadata     = jsonencode(local.tag_policy.properties.metadata)
  parameters   = jsonencode(local.tag_policy.properties.parameters)
  policy_rule  = jsonencode(local.tag_policy.properties.policyRule)
}

resource "azurerm_policy_set_definition" "zero_trust" {
  name         = "ztlz-zero-trust-containers"
  policy_type  = "Custom"
  display_name = "Zero-trust containers (azure-zero-trust-container-lz)"
  description  = "Governance tags, Kubernetes pod security, trusted registry only, Key Vault firewall, and ACR network posture."
  metadata     = jsonencode({ category = "Kubernetes" })

  dynamic "policy_definition_reference" {
    for_each = local.initiative_members
    content {
      reference_id         = policy_definition_reference.key
      policy_definition_id = policy_definition_reference.value.id
      parameter_values     = jsonencode(policy_definition_reference.value.params)
    }
  }
}

resource "azurerm_resource_group_policy_assignment" "zero_trust" {
  name                 = "ztlz-zero-trust"
  display_name         = "Zero-trust containers"
  description          = "Assigned before any workload resource exists, so everything in this resource group is born compliant."
  resource_group_id    = azurerm_resource_group.dev.id
  policy_definition_id = azurerm_policy_set_definition.zero_trust.id

  non_compliance_message {
    content = "Blocked by the zero-trust container landing zone guardrails (github.com/Subash-1507/azure-zero-trust-container-lz)."
  }
}