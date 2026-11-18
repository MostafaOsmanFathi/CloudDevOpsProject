provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  # Empty values mean: use the Azure CLI session or the ARM_CLIENT_ID /
  # ARM_CLIENT_SECRET / ARM_SUBSCRIPTION_ID / ARM_TENANT_ID environment
  # variables.
  subscription_id = var.subscription_id != "" ? var.subscription_id : null
  tenant_id       = var.tenant_id != "" ? var.tenant_id : null
  client_id       = var.client_id != "" ? var.client_id : null
  client_secret   = var.client_secret != "" ? var.client_secret : null

  # The storage account backend locks the state with a blob lease, so a lock
  # table like DynamoDB does not exist on Azure.
  resource_provider_registrations = "none"
}
