variable "name_prefix" {
  description = "Prefix used for every resource name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the cluster."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets used by the cluster."
  type        = list(string)
}

variable "private_subnet_ids_by_az" {
  description = "Map of availability zone to private subnet ID. One node pool is created per entry, so every worker node lands in its own subnet and zone."
  type        = map(string)
}

variable "vnet_id" {
  description = "ID of the virtual network."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version. Empty means the latest version available."
  type        = string
  default     = ""
}

variable "node_vm_size" {
  description = "Size of the AKS nodes."
  type        = string
  default     = "Standard_B2s"
}

variable "node_count" {
  description = "Number of nodes in each node pool. The total is this value multiplied by the number of node pools."
  type        = number
  default     = 1
}

variable "max_pods" {
  description = "Maximum number of pods per node."
  type        = number
  default     = 110
}

variable "min_count" {
  description = "Minimum number of nodes in each node pool."
  type        = number
  default     = 1
}

variable "max_count" {
  description = "Maximum number of nodes in each node pool."
  type        = number
  default     = 2
}

variable "service_cidr" {
  description = "CIDR block of the Kubernetes service network."
  type        = string
  default     = "10.1.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address of the Kubernetes DNS service inside the service CIDR."
  type        = string
  default     = "10.1.0.10"
}

variable "acr_id" {
  description = "ID of the container registry, used to give the kubelet identity the AcrPull role."
  type        = string
}

variable "admin_cidr" {
  description = "CIDR allowed to reach the Kubernetes API server."
  type        = string
  default     = "0.0.0.0/0"
}

variable "availability_zones" {
  description = "Availability zones used for the node pools."
  type        = list(string)
  default     = ["1", "2"]
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
