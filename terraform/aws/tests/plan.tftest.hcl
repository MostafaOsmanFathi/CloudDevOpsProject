# Offline validation of the whole plan. The AWS provider is mocked, so the
# test runs without credentials and without creating any real resource.
#
#   terraform test
#
mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = {
      id           = "ami-0123456789abcdef0"
      image_id     = "ami-0123456789abcdef0"
      architecture = "x86_64"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:root"
      user_id    = "AIDAEXAMPLE"
    }
  }

  mock_data "aws_eks_addon_version" {
    defaults = {
      version = "v1.19.0-eksbuild.1"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\"}"
    }
  }

  mock_resource "aws_eks_cluster" {
    defaults = {
      version = "1.31"
    }
  }
}

variables {
  aws_region = "us-east-1"
}

run "plan_is_valid" {
  command = plan

  assert {
    condition     = length(module.network.public_subnet_ids) == 2
    error_message = "The network module must create one public subnet per availability zone."
  }

  assert {
    condition     = length(module.network.private_subnet_ids_by_az) == 2
    error_message = "The network module must create one private subnet per availability zone."
  }

  assert {
    condition     = length(module.eks.node_group_names) == 2
    error_message = "EKS must have one node group per availability zone, so two worker nodes in two subnets."
  }

  assert {
    condition     = length(module.ecr.repository_urls) == 3
    error_message = "ECR must hold one repository per microservice."
  }
}
