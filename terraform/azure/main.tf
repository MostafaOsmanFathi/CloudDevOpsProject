resource "azurerm_resource_group" "this" {
  location = var.location
  name     = local.resource_group_name

  tags = local.common_tags
}

module "network" {
  source = "./modules/network"

  name_prefix          = var.project_name
  location             = var.location
  resource_group_name  = azurerm_resource_group.this.name
  vnet_cidr            = var.vnet_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
  admin_cidr           = var.admin_cidr
  tags                 = local.common_tags
}

module "acr" {
  source = "./modules/acr"

  name_prefix              = var.project_name
  location                 = var.location
  resource_group_name      = azurerm_resource_group.this.name
  sku                      = var.acr_sku
  retention_policy_in_days = var.acr_retention_days
  tags                     = local.common_tags
}

module "server" {
  source = "./modules/server"

  name_prefix             = var.project_name
  location                = var.location
  resource_group_name     = azurerm_resource_group.this.name
  public_subnet_ids       = module.network.public_subnet_ids
  public_subnet_ids_by_az = module.network.public_subnet_ids_by_az
  vm_size                 = var.vm_size
  jenkins_dns_label       = var.jenkins_dns_label
  admin_username          = var.vm_admin_username
  admin_ssh_public_key    = var.vm_admin_ssh_public_key
  os_disk_size_gb         = var.vm_os_disk_size_gb
  admin_cidr              = var.admin_cidr
  acr_id                  = module.acr.registry_id
  tags                    = local.common_tags
}

module "aks" {
  source = "./modules/aks"

  name_prefix              = var.project_name
  location                 = var.location
  resource_group_name      = azurerm_resource_group.this.name
  private_subnet_ids       = module.network.private_subnet_ids
  private_subnet_ids_by_az = module.network.private_subnet_ids_by_az
  kubernetes_version       = var.aks_kubernetes_version
  node_vm_size             = var.aks_node_vm_size
  node_count               = var.aks_node_count
  max_pods                 = var.aks_max_pods
  min_count                = var.aks_min_count
  max_count                = var.aks_max_count
  system_node_count        = var.aks_system_node_count
  system_min_count         = var.aks_system_min_count
  system_max_count         = var.aks_system_max_count
  service_cidr             = var.aks_service_cidr
  dns_service_ip           = var.aks_dns_service_ip
  vnet_id                  = module.network.vnet_id
  acr_id                   = module.acr.registry_id
  admin_cidr               = var.admin_cidr
  tags                     = local.common_tags
}
