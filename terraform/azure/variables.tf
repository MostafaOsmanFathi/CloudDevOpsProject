variable "subscription_id" {
  description = "Azure subscription id."
  type        = string
  default     = ""
}

variable "tenant_id" {
  description = "Azure tenant id. Only needed for service principal authentication."
  type        = string
  default     = ""
}

variable "client_id" {
  description = "Client id of the Azure service principal. Leave empty to use the Azure CLI session."
  type        = string
  default     = ""
}

variable "client_secret" {
  description = "Client secret of the Azure service principal. Leave empty to use the Azure CLI session."
  type        = string
  default     = ""
  sensitive   = true
}

variable "location" {
  description = "Azure region where the infrastructure is created."
  type        = string
  default     = "West Europe"
}

variable "project_name" {
  description = "Name prefix applied to every resource."
  type        = string
  default     = "ivolve"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "resource_group_name" {
  description = "Resource group that holds the infrastructure. Empty means <project>-<environment>-rg."
  type        = string
  default     = ""
}

variable "admin_cidr" {
  description = "CIDR allowed to reach SSH on the Jenkins server. Lock this down to your own IP."
  type        = string
  default     = "0.0.0.0/0"
}

variable "vnet_cidr" {
  description = "CIDR block of the virtual network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones used for the subnets and node pools."
  type        = list(string)
  default     = ["1", "2"]
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

variable "vm_size" {
  description = "Size of the VM for the Jenkins server."
  type        = string
  default     = "Standard_B2s"
}

variable "vm_admin_username" {
  description = "Admin user of the Jenkins VM."
  type        = string
  default     = "azureuser"
}

variable "vm_admin_ssh_public_key" {
  description = "Public key for SSH. When empty, password authentication is used and a random password is generated."
  type        = string
  default     = ""
}

variable "vm_os_disk_size_gb" {
  description = "OS disk size of the Jenkins VM."
  type        = number
  default     = 64
}

variable "aks_kubernetes_version" {
  description = "Kubernetes version of the AKS cluster. Empty means the latest available version."
  type        = string
  default     = ""
}

variable "aks_node_vm_size" {
  description = "Size of the AKS node pools."
  type        = string
  default     = "Standard_B2s"
}

variable "aks_max_pods" {
  description = "Maximum number of pods per node."
  type        = number
  default     = 110
}

variable "aks_node_count" {
  description = "Number of nodes in each node pool. One node pool per availability zone, so the total is this value multiplied by the number of availability zones."
  type        = number
  default     = 1
}

variable "aks_min_count" {
  description = "Minimum number of nodes in each node pool."
  type        = number
  default     = 1
}

variable "aks_max_count" {
  description = "Maximum number of nodes in each node pool."
  type        = number
  default     = 2
}

variable "aks_service_cidr" {
  description = "CIDR block of the Kubernetes service network."
  type        = string
  default     = "10.1.0.0/16"
}

variable "aks_dns_service_ip" {
  description = "IP address of the Kubernetes DNS service inside the service CIDR."
  type        = string
  default     = "10.1.0.10"
}

variable "acr_sku" {
  description = "SKU of the Azure Container Registry."
  type        = string
  default     = "Standard"
}

variable "acr_retention_days" {
  description = "Number of days an ACR manifest is retained before the related layers are deleted."
  type        = number
  default     = 7
}

variable "acr_max_manifests" {
  description = "Number of images kept per repository before old manifests expire (a task is not used, this value is documented for tagging)."
  type        = number
  default     = 10
}

variable "tags" {
  description = "Extra tags merged into every resource."
  type        = map(string)
  default     = {}
}
