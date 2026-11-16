output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids_by_az" {
  description = "Map of availability zone to public subnet ID."
  value       = { for idx, az in var.availability_zones : az => aws_subnet.public[idx].id }
}

output "private_subnet_ids_by_az" {
  description = "Map of availability zone to private subnet ID."
  value       = { for idx, az in var.availability_zones : az => aws_subnet.private[idx].id }
}

output "internet_gateway_id" {
  description = "ID of the internet gateway."
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways."
  value       = aws_nat_gateway.this[*].id
}

output "nat_public_ips" {
  description = "Elastic IPs of the NAT gateways."
  value       = aws_eip.nat[*].public_ip
}

output "network_acl_ids" {
  description = "IDs of the custom network ACLs."
  value = {
    public  = aws_network_acl.public.id
    private = aws_network_acl.private.id
  }
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs of the private route tables."
  value       = aws_route_table.private[*].id
}
