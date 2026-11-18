output "vnet_id" {
  description = "ID of the virtual network."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the virtual network."
  value       = azurerm_virtual_network.this.name
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = azurerm_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = azurerm_subnet.private[*].id
}

output "public_subnet_ids_by_az" {
  description = "Map of availability zone to public subnet ID."
  value       = { for idx, az in var.availability_zones : az => azurerm_subnet.public[idx].id }
}

output "private_subnet_ids_by_az" {
  description = "Map of availability zone to private subnet ID."
  value       = { for idx, az in var.availability_zones : az => azurerm_subnet.private[idx].id }
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways."
  value       = azurerm_nat_gateway.this[*].id
}

output "nat_public_ips" {
  description = "Public IPs of the NAT gateways."
  value       = azurerm_public_ip.nat[*].ip_address
}

output "network_security_group_ids" {
  description = "IDs of the network security groups."
  value = {
    public  = azurerm_network_security_group.public.id
    private = azurerm_network_security_group.private.id
  }
}
