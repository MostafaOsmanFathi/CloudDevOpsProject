variable "aws_region" {
  description = "AWS region where the infrastructure is created."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Named profile from ~/.aws/credentials. Leave empty to use the default credential chain (env vars or default profile)."
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Name prefix applied to every resource so the stack is easy to identify."
  type        = string
  default     = "ivolve"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "admin_cidr" {
  description = "CIDR allowed to reach SSH on the Jenkins server. Lock this down to your own IP."
  type        = string
  default     = "0.0.0.0/0"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones used for the public and private subnets."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets (one per availability zone)."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets (one per availability zone)."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway for every private subnet (cheaper, single point of failure) instead of one per availability zone."
  type        = bool
  default     = false
}

variable "jenkins_instance_type" {
  description = "EC2 instance type for the Jenkins server."
  type        = string
  default     = "t3.medium"
}

variable "jenkins_ami_id" {
  description = "AMI for the Jenkins server. Empty means the latest Amazon Linux 2023 AMI is resolved automatically."
  type        = string
  default     = ""
}

variable "jenkins_root_volume_size" {
  description = "Root EBS volume size (GB) for the Jenkins server."
  type        = number
  default     = 30
}

variable "ssh_key_name" {
  description = "Name of an existing EC2 key pair for SSH access. Empty means keyless access through SSM Session Manager."
  type        = string
  default     = ""
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "ivolve-eks"
}

variable "eks_kubernetes_version" {
  description = "Kubernetes version of the EKS cluster. Empty means the latest version available in the region."
  type        = string
  default     = ""
}

variable "eks_endpoint_public_access" {
  description = "Expose the Kubernetes API server to the internet."
  type        = bool
  default     = true
}

variable "eks_endpoint_public_cidrs" {
  description = "CIDR blocks allowed to reach the public Kubernetes API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eks_node_instance_types" {
  description = "EC2 instance types used by the EKS worker nodes."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_desired_size" {
  description = "Desired number of nodes in each node group. There is one node group per private subnet, so the total is this value multiplied by the number of private subnets."
  type        = number
  default     = 1
}

variable "eks_node_min_size" {
  description = "Minimum number of nodes in each node group."
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of nodes in each node group."
  type        = number
  default     = 2
}

variable "ecr_repository_names" {
  description = "ECR repositories created for the microservices."
  type        = list(string)
  default     = ["frontend", "auth-service", "roadmap-service"]
}

variable "ecr_max_images" {
  description = "Number of images kept in each ECR repository before the oldest ones expire."
  type        = number
  default     = 10
}

variable "tags" {
  description = "Extra tags merged into every resource."
  type        = map(string)
  default     = {}
}
