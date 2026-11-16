variable "name_prefix" {
  description = "Prefix used for every repository name."
  type        = string
}

variable "repository_names" {
  description = "Names of the ECR repositories to create."
  type        = list(string)
}

variable "image_tag_mutability" {
  description = "MUTABLE or IMMUTABLE tags."
  type        = string
  default     = "IMMUTABLE"
}

variable "encryption_type" {
  description = "AES256 or KMS."
  type        = string
  default     = "AES256"
}

variable "kms_key_arn" {
  description = "KMS key ARN used when encryption_type is KMS."
  type        = string
  default     = ""
}

variable "scan_on_push" {
  description = "Scan every image with Trivy/Inspector when it is pushed."
  type        = bool
  default     = true
}

variable "force_delete" {
  description = "Allow deleting a repository that still holds images."
  type        = bool
  default     = true
}

variable "max_images" {
  description = "Number of images kept before the oldest ones expire."
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags applied to every repository."
  type        = map(string)
  default     = {}
}
