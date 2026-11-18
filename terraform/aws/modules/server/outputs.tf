output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.server.id
}

output "public_ip" {
  description = "Public IP of the instance."
  value       = var.assign_eip ? aws_eip.server[0].public_ip : aws_instance.server.public_ip
}

output "private_ip" {
  description = "Private IP of the instance."
  value       = aws_instance.server.private_ip
}

output "ami_id" {
  description = "AMI used by the instance."
  value       = aws_instance.server.ami
}

output "subnet_id" {
  description = "Subnet the instance is attached to."
  value       = aws_instance.server.subnet_id
}

output "security_group_id" {
  description = "ID of the security group attached to the instance."
  value       = aws_security_group.server.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role attached to the instance."
  value       = aws_iam_role.server.arn
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile attached to the instance."
  value       = aws_iam_instance_profile.server.name
}
