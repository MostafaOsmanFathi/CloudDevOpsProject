variable "name_prefix" {
  description = "Prefix used for every resource name."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
}

variable "availability_zones" {
  description = "Availability zones used for the subnets."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets (one per availability zone)."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets (one per availability zone)."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway for all private subnets instead of one per availability zone."
  type        = bool
  default     = false
}

variable "admin_cidr" {
  description = "CIDR allowed to reach SSH inside the VPC."
  type        = string
  default     = "0.0.0.0/0"
}

variable "cluster_name" {
  description = "EKS cluster name used in the subnet discovery tags. Leave empty to skip the EKS tags."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
