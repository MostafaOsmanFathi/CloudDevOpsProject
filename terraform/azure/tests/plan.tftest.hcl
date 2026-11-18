# Offline validation of the whole plan. The Azure provider is mocked, so the
# test runs without credentials and without creating any real resource.
#
#   terraform test
#
mock_provider "azurerm" {
  mock_resource "azurerm_kubernetes_cluster" {
    defaults = {
      current_kubernetes_version = "1.30.6"
      fqdn                       = "mock.fqdn"
      oidc_issuer_url            = "https://mock.example.com"
      kube_config_raw            = base64encode("mock-kubeconfig")
    }
  }

  mock_resource "azurerm_kubernetes_cluster_node_pool" {
    defaults = {}
  }
}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  location        = "West Europe"
}

run "plan_is_valid" {
  command = plan

  assert {
    condition     = length(module.network.public_subnet_ids) == 2
    error_message = "The network module must create one public subnet per availability zone."
  }

  assert {
    condition     = length(module.network.private_subnet_ids_by_az) == 2
    error_message = "The network module must create one private subnet per availability zone."
  }

  assert {
    condition     = length(module.aks.node_pool_names.workers) == 2
    error_message = "AKS must have one user node pool per availability zone."
  }

  assert {
    condition     = length(module.network.private_subnet_ids) == 2
    error_message = "There must be one private subnet per availability zone."
  }
}
