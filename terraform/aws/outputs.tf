output "vpc_id" {
  description = "ID of the VPC."
  value       = module.network.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = module.network.vpc_cidr_block
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

output "network_acl_ids" {
  description = "IDs of the custom network ACLs."
  value       = module.network.network_acl_ids
}

output "jenkins_instance_id" {
  description = "ID of the Jenkins EC2 instance."
  value       = module.server.instance_id
}

output "jenkins_public_ip" {
  description = "Public IP of the Jenkins server."
  value       = module.server.public_ip
}

output "jenkins_private_ip" {
  description = "Private IP of the Jenkins server."
  value       = module.server.private_ip
}

output "jenkins_security_group_id" {
  description = "ID of the Jenkins security group."
  value       = module.server.security_group_id
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint of the Kubernetes API server."
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_oidc_issuer" {
  description = "OIDC issuer URL of the cluster, needed to set up IAM Roles for Service Accounts."
  value       = module.eks.oidc_issuer
}

output "eks_node_group_names" {
  description = "Names of the EKS node groups (one per availability zone)."
  value       = module.eks.node_group_names
}

output "ecr_repository_urls" {
  description = "URLs of the ECR repositories."
  value       = module.ecr.repository_urls
}

output "ecr_repository_names" {
  description = "Names of the ECR repositories."
  value       = module.ecr.repository_names
}
