variable "name_prefix" {
  description = "Prefix used for every resource name."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the server is created."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC, used for the internal traffic rule."
  type        = string
}

variable "subnet_id" {
  description = "Subnet the server is attached to."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "AMI to use. Empty means the latest Amazon Linux 2023 AMI is resolved automatically."
  type        = string
  default     = ""
}

variable "key_name" {
  description = "Name of an existing EC2 key pair. Empty means keyless access through SSM Session Manager."
  type        = string
  default     = ""
}

variable "admin_cidr" {
  description = "CIDR allowed to reach SSH."
  type        = string
  default     = "0.0.0.0/0"
}

variable "jenkins_ui_cidrs" {
  description = "CIDR blocks allowed to reach the Jenkins web interface."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB."
  type        = number
  default     = 30
}

variable "assign_eip" {
  description = "Attach an Elastic IP so the public address stays stable."
  type        = bool
  default     = true
}

variable "user_data" {
  description = "Optional cloud-init script. Ansible is responsible for the Jenkins installation."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
