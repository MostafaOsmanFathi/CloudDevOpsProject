output "repository_names" {
  description = "Names of the ECR repositories."
  value       = [for repo in aws_ecr_repository.this : repo.name]
}

output "repository_arns" {
  description = "ARNs of the ECR repositories."
  value       = [for repo in aws_ecr_repository.this : repo.arn]
}

output "repository_urls" {
  description = "URLs of the ECR repositories, ready to be used by docker login and docker push."
  value       = [for repo in aws_ecr_repository.this : repo.repository_url]
}

output "registry_id" {
  description = "AWS account ID that owns the registry."
  value       = data.aws_caller_identity.current.account_id
}
