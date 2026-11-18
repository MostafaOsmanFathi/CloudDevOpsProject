data "azurerm_client_config" "current" {}

locals {
  resource_group_name  = var.resource_group_name != "" ? var.resource_group_name : "${var.project_name}-state-rg"
  storage_account_name = var.storage_account_name != "" ? var.storage_account_name : "${var.project_name}state${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# -----------------------------------------------------------------------------
# Resource group for the state resources
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "state" {
  location = var.location
  name     = local.resource_group_name

  tags = merge(var.tags, {
    Name = local.resource_group_name
  })
}

# -----------------------------------------------------------------------------
# Storage account holding the state file
# The azurerm backend locks the state with a blob lease, a separate lock
# table like DynamoDB does not exist on Azure.
# -----------------------------------------------------------------------------

resource "azurerm_storage_account" "state" {
  location                        = var.location
  name                            = local.storage_account_name
  resource_group_name             = azurerm_resource_group.state.name
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true
  }

  tags = merge(var.tags, {
    Name = local.storage_account_name
  })
}

resource "azurerm_storage_container" "state" {
  storage_account_name  = azurerm_storage_account.state.name
  name                  = var.container_name
  container_access_type = "private"
}

# Grant the current identity read and write access so the backend can use
# Azure AD authentication instead of the account access key.
resource "azurerm_role_assignment" "blob_data_contributor" {
  count = var.assign_blob_data_contributor ? 1 : 0

  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
  scope                = azurerm_storage_account.state.id
}
