provider "aws" {
  region = var.aws_region

  # Credentials can come from three places, in this order:
  #   1. the variables below (set them in the gitignored terraform.tfvars)
  #   2. AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN
  #   3. ~/.aws/credentials, the "profile" below, or the instance profile
  # Leaving the variables empty keeps the standard credential chain working.
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  token      = var.aws_session_token

  # Leave empty to use the standard credential chain:
  #   1. AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN
  #   2. ~/.aws/credentials  (profile "default")
  #   3. AWS_PROFILE / AWS_SDK_LOAD_CONFIG
  # Set it to a named profile when using SSO / IAM Identity Center.
  profile = var.aws_profile != "" ? var.aws_profile : null

  default_tags {
    tags = local.common_tags
  }
}
