provider "aws" {
  region = var.aws_region

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
