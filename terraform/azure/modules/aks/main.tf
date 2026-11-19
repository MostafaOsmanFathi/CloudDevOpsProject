locals {
  azs = sort(var.availability_zones)
}

# -----------------------------------------------------------------------------
# System node pool - one node per availability zone
# -----------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster" "this" {
  location            = var.location
  name                = "${var.name_prefix}-aks"
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.name_prefix}-aks"
  kubernetes_version  = var.kubernetes_version != "" ? var.kubernetes_version : null
  sku_tier            = "Standard"

  identity {
    type = "SystemAssigned"
  }

  node_provisioning_profile {
    mode = "Manual"
  }

  default_node_pool {
    name                 = "system"
    vm_size              = var.node_vm_size
    node_count           = var.system_node_count
    min_count            = var.system_min_count
    max_count            = var.system_max_count
    max_pods             = var.max_pods
    auto_scaling_enabled = true
    os_disk_size_gb      = 64
    os_disk_type         = "Managed"
    os_sku               = "AzureLinux"
    type                 = "VirtualMachineScaleSets"

    vnet_subnet_id = var.private_subnet_ids_by_az[local.azs[0]]

    # Declared explicitly so the API defaults do not show up as a perpetual diff.
    upgrade_settings {
      max_surge = "10%"
    }
  }

  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    network_data_plane = "azure"
    load_balancer_sku  = "standard"
    # Egress goes through the NAT gateway that the network module already
    # associated with the private subnets. The default "loadBalancer" makes AKS
    # create its own outbound public IP, and the subscription is capped at 3
    # public IPs per region (Jenkins + NAT gateway + AKS API server already
    # use all of them).
    outbound_type  = "userAssignedNATGateway"
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
  }

  api_server_access_profile {
    authorized_ip_ranges = [var.admin_cidr]
  }

  role_based_access_control_enabled = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-aks"
  })
}

# -----------------------------------------------------------------------------
# User node pools - one pool per availability zone
#
# The pools stay empty while the subscription is limited to 6 regional vCPUs:
# the system pool (4) and the Jenkins VM (2) already use all of them. Raise
# aks_node_count and aks_max_count together, only after the quota increases.
# -----------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster_node_pool" "workers" {
  for_each = var.private_subnet_ids_by_az

  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  name                  = "user${each.key}"
  vm_size               = var.node_vm_size
  mode                  = "User"
  node_count            = var.node_count
  min_count             = var.min_count
  max_count             = var.max_count
  max_pods              = var.max_pods
  auto_scaling_enabled  = true
  os_disk_size_gb       = 64
  os_disk_type          = "Managed"
  os_sku                = "AzureLinux"
  vnet_subnet_id        = each.value

  # Declared explicitly so the API defaults do not show up as a perpetual diff.
  upgrade_settings {
    max_surge = "10%"
  }

  node_labels = {
    "node-role" = "worker"
    "zone"      = each.key
  }

  tags = merge(var.tags, {
    "Name" = "${var.name_prefix}-workers-${each.key}"
  })
}

# -----------------------------------------------------------------------------
# Registry access
# -----------------------------------------------------------------------------

resource "azurerm_role_assignment" "acr_pull" {
  role_definition_name = "AcrPull"
  principal_id         = try(azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id, azurerm_kubernetes_cluster.this.identity[0].principal_id)
  scope                = var.acr_id
}
