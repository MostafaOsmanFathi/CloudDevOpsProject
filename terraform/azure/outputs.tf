output "resource_group_name" {
  description = "Name of the resource group."
  value       = azurerm_resource_group.this.name
}

output "vnet_id" {
  description = "ID of the virtual network."
  value       = module.network.vnet_id
}

output "vnet_name" {
  description = "Name of the virtual network."
  value       = module.network.vnet_name
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = module.network.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways."
  value       = module.network.nat_gateway_ids
}

output "nat_public_ips" {
  description = "Public IPs of the NAT gateways."
  value       = module.network.nat_public_ips
}

output "jenkins_vm_id" {
  description = "ID of the Jenkins VM."
  value       = module.server.vm_id
}

output "jenkins_public_ip" {
  description = "Public IP of the Jenkins server."
  value       = module.server.public_ip
}

output "jenkins_private_ip" {
  description = "Private IP of the Jenkins server."
  value       = module.server.private_ip
}

output "jenkins_user_assigned_identity_id" {
  description = "ID of the user assigned identity attached to the VM."
  value       = module.server.user_assigned_identity_id
}

output "jenkins_generated_admin_password" {
  description = "Random admin password, only set when no SSH public key is provided."
  value       = module.server.generated_admin_password
  sensitive   = true
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster."
  value       = module.aks.cluster_name
}

output "aks_api_server_fqdn" {
  description = "FQDN of the Kubernetes API server."
  value       = module.aks.api_server_fqdn
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL, used for workload identity."
  value       = module.aks.oidc_issuer_url
}

output "aks_node_pool_names" {
  description = "Names of the node pools."
  value       = module.aks.node_pool_names
}

output "acr_registry_name" {
  description = "Name of the Azure Container Registry."
  value       = module.acr.registry_name
}

output "acr_login_server" {
  description = "Login server of the Azure Container Registry."
  value       = module.acr.login_server
}

output "acr_registry_url" {
  description = "URL of the registry, same as the login server."
  value       = module.acr.registry_url
}
