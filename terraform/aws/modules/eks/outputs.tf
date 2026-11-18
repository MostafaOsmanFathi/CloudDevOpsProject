output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Endpoint of the Kubernetes API server."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate authority of the cluster."
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "oidc_issuer" {
  description = "OIDC issuer URL of the cluster, used to set up IAM Roles for Service Accounts."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "node_group_names" {
  description = "Names of the node groups, one per availability zone."
  value       = [for az, ng in aws_eks_node_group.workers : ng.node_group_name]
}

output "node_group_arns" {
  description = "ARNs of the node groups."
  value       = [for az, ng in aws_eks_node_group.workers : ng.arn]
}

output "node_group_subnet_ids" {
  description = "Subnet used by each node group."
  value       = { for az, ng in aws_eks_node_group.workers : az => ng.subnet_ids }
}

output "cluster_role_arn" {
  description = "ARN of the IAM role used by the control plane."
  value       = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  description = "ARN of the IAM role used by the worker nodes."
  value       = aws_iam_role.node.arn
}

output "aws_account_id" {
  description = "AWS account ID the cluster runs in."
  value       = data.aws_caller_identity.current.account_id
}
