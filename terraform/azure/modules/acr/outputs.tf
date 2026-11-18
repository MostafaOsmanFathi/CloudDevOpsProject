output "registry_id" {
  description = "ID of the Azure Container Registry."
  value       = azurerm_container_registry.this.id
}

output "registry_name" {
  description = "Name of the registry."
  value       = azurerm_container_registry.this.name
}

output "login_server" {
  description = "Login server of the registry, used by docker login."
  value       = azurerm_container_registry.this.login_server
}

output "registry_url" {
  description = "Registry URL, same as the login server."
  value       = azurerm_container_registry.this.login_server
}

output "repositories" {
  description = "The repositories this registry is planned to hold. They are created implicitly on the first push."
  value       = ["ivolve-frontend", "ivolve-auth-service", "ivolve-roadmap-service"]
}
