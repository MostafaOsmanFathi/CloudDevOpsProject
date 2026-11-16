variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the cluster is created."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets used by the cluster control plane."
  type        = list(string)
}

variable "private_subnet_ids_by_az" {
  description = "Map of availability zone to private subnet ID. One node group is created per entry, so every worker node lands in its own subnet and availability zone."
  type        = map(string)
}

variable "kubernetes_version" {
  description = "Kubernetes version. Empty means the latest version available in the region."
  type        = string
  default     = ""
}

variable "endpoint_public_access" {
  description = "Expose the Kubernetes API server to the internet."
  type        = bool
  default     = true
}

variable "endpoint_public_cidrs" {
  description = "CIDR blocks allowed to reach the public Kubernetes API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  description = "EC2 instance types used by the worker nodes."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_ami_type" {
  description = "AMI type of the worker nodes."
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "node_desired_size" {
  description = "Desired number of nodes in each node group."
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "Minimum number of nodes in each node group."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes in each node group."
  type        = number
  default     = 2
}

variable "enabled_addons" {
  description = "Managed EKS addons to manage with Terraform."
  type        = list(string)
  default     = ["vpc-cni", "coredns"]
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
