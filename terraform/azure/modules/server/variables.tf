variable "name_prefix" {
  description = "Prefix used for every resource name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the VM."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets the VM can be placed in. The first entry is used."
  type        = list(string)
}

variable "public_subnet_ids_by_az" {
  description = "Map of availability zone to public subnet ID."
  type        = map(string)
}

variable "vm_size" {
  description = "Size of the virtual machine."
  type        = string
  default     = "Standard_B2s"
}

variable "jenkins_dns_label" {
  description = "DNS name label of the public IP. The FQDN becomes <label>.<location>.cloudapp.azure.com, which is how the application is reached. Must be globally unique."
  type        = string
  default     = "ivolve"
}

variable "admin_username" {
  description = "Admin user of the VM."
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "Public key for SSH. When empty, password authentication is used and a random password is generated."
  type        = string
  default     = ""
}

variable "os_disk_size_gb" {
  description = "Size of the OS disk."
  type        = number
  default     = 64
}

variable "admin_cidr" {
  description = "CIDR allowed to reach SSH and the Jenkins UI."
  type        = string
  default     = "0.0.0.0/0"
}

variable "acr_id" {
  description = "ID of the container registry. The identity of the VM gets the AcrPull role on it."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
