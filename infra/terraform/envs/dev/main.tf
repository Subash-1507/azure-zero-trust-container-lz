locals {
  tags = {
    Environment        = "dev"
    CostCenter         = var.cost_center
    DataClassification = "Internal"
    Project            = "azure-zero-trust-container-lz"
    ManagedBy          = "terraform"
  }
}

# Shared suffix for globally unique names (the ACR name is known now, so the image policy can trust it)
resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "azurerm_resource_group" "dev" {
  name     = "rg-ztlz-dev"
  location = var.location
  tags     = local.tags
}
