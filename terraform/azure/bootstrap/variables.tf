variable "subscription_id" {
  description = "Azure subscription id."
  type        = string
  default     = ""
}

variable "tenant_id" {
  description = "Azure tenant id."
  type        = string
  default     = ""
}

variable "client_id" {
  description = "Client id of the service principal. Leave empty to use the Azure CLI session."
  type        = string
  default     = ""
}

variable "client_secret" {
  description = "Client secret of the service principal. Leave empty to use the Azure CLI session."
  type        = string
  default     = ""
  sensitive   = true
}

variable "location" {
  description = "Azure region where the state bucket is created."
  type        = string
  default     = "East US"
}

variable "project_name" {
  description = "Project name used in the names of the state resources."
  type        = string
  default     = "ivolvedevops"
}

variable "resource_group_name" {
  description = "Name of the resource group for the state resources. Empty means <project>-state-rg."
  type        = string
  default     = ""
}

variable "storage_account_name" {
  description = "Name of the storage account for the state file. Empty means <project>state<random>."
  type        = string
  default     = ""
}

variable "container_name" {
  description = "Name of the blob container that holds the state file."
  type        = string
  default     = "tfstate"
}

variable "assign_blob_data_contributor" {
  description = "Grant the current identity the Storage Blob Data Contributor role on the storage account. Required for Azure AD backend authentication."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
