module "network" {
  source = "./modules/network"

  name_prefix          = var.project_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
  admin_cidr           = var.admin_cidr
  cluster_name         = var.eks_cluster_name
  tags                 = local.common_tags
}

module "ecr" {
  source = "./modules/ecr"

  name_prefix      = var.project_name
  repository_names = var.ecr_repository_names
  max_images       = var.ecr_max_images
  tags             = local.common_tags
}

module "server" {
  source = "./modules/server"

  name_prefix      = var.project_name
  vpc_id           = module.network.vpc_id
  vpc_cidr         = module.network.vpc_cidr_block
  subnet_id        = module.network.public_subnet_ids[0]
  instance_type    = var.jenkins_instance_type
  ami_id           = var.jenkins_ami_id
  key_name         = var.ssh_key_name
  admin_cidr       = var.admin_cidr
  root_volume_size = var.jenkins_root_volume_size
  assign_eip       = true
  tags             = local.common_tags
}

module "eks" {
  source = "./modules/eks"

  cluster_name             = var.eks_cluster_name
  vpc_id                   = module.network.vpc_id
  private_subnet_ids       = module.network.private_subnet_ids
  private_subnet_ids_by_az = module.network.private_subnet_ids_by_az
  kubernetes_version       = var.eks_kubernetes_version
  endpoint_public_access   = var.eks_endpoint_public_access
  endpoint_public_cidrs    = var.eks_endpoint_public_cidrs
  node_instance_types      = var.eks_node_instance_types
  node_desired_size        = var.eks_node_desired_size
  node_min_size            = var.eks_node_min_size
  node_max_size            = var.eks_node_max_size
  tags                     = local.common_tags
}
