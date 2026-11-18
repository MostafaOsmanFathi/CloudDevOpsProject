variable "name_prefix" {
  description = "Prefix used for every resource name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the network."
  type        = string
}

variable "vnet_cidr" {
  description = "CIDR block of the virtual network."
  type        = string
}

variable "availability_zones" {
  description = "Availability zones used for the subnets and NAT gateways."
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
  description = "CIDR allowed to reach SSH inside the virtual network."
  type        = string
  default     = "0.0.0.0/0"
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
