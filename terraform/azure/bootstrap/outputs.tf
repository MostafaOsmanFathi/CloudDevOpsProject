output "resource_group_name" {
  description = "Name of the resource group that holds the state resources."
  value       = azurerm_resource_group.state.name
}

output "storage_account_name" {
  description = "Name of the storage account holding the state file."
  value       = azurerm_storage_account.state.name
}

output "container_name" {
  description = "Name of the blob container holding the state file."
  value       = azurerm_storage_container.state.name
}

output "backend_config" {
  description = "Ready to use backend configuration for the parent directory."
  value       = <<-EOT
    storage_account_name = "${azurerm_storage_account.state.name}"
    container_name        = "${azurerm_storage_container.state.name}"
    key                    = "terraform.tfstate"
    resource_group_name    = "${azurerm_resource_group.state.name}"
    use_azuread_auth       = true
  EOT
}
