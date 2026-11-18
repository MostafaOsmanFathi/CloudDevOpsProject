resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# -----------------------------------------------------------------------------
# Registry
# -----------------------------------------------------------------------------

resource "azurerm_container_registry" "this" {
  name                = "${var.name_prefix}acr${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  admin_enabled       = false

  # The retention policy is only available on the Premium SKU.
  retention_policy_in_days   = var.sku == "Premium" ? var.retention_policy_in_days : null
  quarantine_policy_enabled  = false
  data_endpoint_enabled      = false
  network_rule_bypass_option = "AzureServices"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-acr"
  })
}
