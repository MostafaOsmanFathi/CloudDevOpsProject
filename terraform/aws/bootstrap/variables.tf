variable "aws_region" {
  description = "AWS region where the state bucket is created."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Named profile from ~/.aws/credentials. Leave empty to use the default credential chain."
  type        = string
  default     = ""
}

variable "bucket_name" {
  description = "Name of the S3 bucket holding the Terraform state. Empty means <project>-tfstate-<account id>."
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Project name used in the default bucket name."
  type        = string
  default     = "ivolve-devops"
}

variable "lock_table_name" {
  description = "Name of the DynamoDB table used to lock the state."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to the state bucket."
  type        = map(string)
  default     = {}
}
