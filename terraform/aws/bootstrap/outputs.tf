output "bucket_name" {
  description = "Name of the S3 bucket holding the Terraform state. Copy it into backend.hcl."
  value       = aws_s3_bucket.state.id
}

output "bucket_arn" {
  description = "ARN of the state bucket."
  value       = aws_s3_bucket.state.arn
}

output "bucket_region" {
  description = "Region of the state bucket."
  value       = var.aws_region
}

output "lock_table_name" {
  description = "Name of the DynamoDB lock table. Copy it into backend.hcl."
  value       = aws_dynamodb_table.locks.name
}

output "backend_config" {
  description = "Ready to use backend configuration for the parent directory."
  value       = <<-EOT
    bucket         = "${aws_s3_bucket.state.id}"
    key            = "terraform.tfstate"
    region         = "${var.aws_region}"
    encrypt        = true
    dynamodb_table = "${aws_dynamodb_table.locks.name}"
  EOT
}
