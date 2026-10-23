# Partial backend config: account-specific values live in backend.hcl (git-ignored).
terraform {
  backend "azurerm" {
    key              = "dev/terraform.tfstate"
    use_azuread_auth = true # Entra ID + RBAC; the state account has shared keys disabled
  }
}
