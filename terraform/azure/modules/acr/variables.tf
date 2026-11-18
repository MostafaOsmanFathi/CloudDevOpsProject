variable "name_prefix" {
  description = "Prefix used for the registry name. The final name is <prefix>acr<random>."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the registry."
  type        = string
}

variable "sku" {
  description = "SKU of the registry (Basic, Standard or Premium)."
  type        = string
  default     = "Standard"
}

variable "retention_policy_in_days" {
  description = "Number of days a manifest is retained before ACR deletes it and its unreferenced layers."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags applied to the registry."
  type        = map(string)
  default     = {}
}
