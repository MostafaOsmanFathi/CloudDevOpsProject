output "cluster_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.name
}

output "cluster_id" {
  description = "ID of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.id
}

output "kube_config_raw" {
  description = "Kubeconfig of the cluster, base64 encoded. Sensitive."
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
}

output "kube_config" {
  description = "Kubeconfig of the cluster. Sensitive."
  value       = azurerm_kubernetes_cluster.this.kube_config
  sensitive   = true
}

output "api_server_fqdn" {
  description = "FQDN of the Kubernetes API server."
  value       = azurerm_kubernetes_cluster.this.fqdn
}

output "portal_fqdn" {
  description = "FQDN of the cluster in the Azure portal."
  value       = azurerm_kubernetes_cluster.this.portal_fqdn
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL, used to set up workload identity."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  description = "Object id of the kubelet identity, which has the AcrPull role on the registry."
  value       = try(azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id, "")
}

output "cluster_identity_principal_id" {
  description = "Principal id of the cluster system assigned identity."
  value       = azurerm_kubernetes_cluster.this.identity[0].principal_id
}

output "node_pool_names" {
  description = "Names of the node pools."
  value = {
    system  = azurerm_kubernetes_cluster.this.default_node_pool[0].name
    workers = { for az, pool in azurerm_kubernetes_cluster_node_pool.workers : az => pool.name }
  }
}

output "node_pool_subnet_ids" {
  description = "Subnet used by each node pool."
  value       = { for az, pool in azurerm_kubernetes_cluster_node_pool.workers : az => pool.vnet_subnet_id }
}

output "node_pool_zones" {
  description = "Zone used by each node pool."
  value       = { for az, pool in azurerm_kubernetes_cluster_node_pool.workers : az => pool.zones }
}

output "current_kubernetes_version" {
  description = "Kubernetes version the cluster runs."
  value       = azurerm_kubernetes_cluster.this.current_kubernetes_version
}
