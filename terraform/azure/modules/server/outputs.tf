output "vm_id" {
  description = "ID of the Jenkins virtual machine."
  value       = azurerm_linux_virtual_machine.jenkins.id
}

output "public_ip" {
  description = "Public IP of the Jenkins server."
  value       = azurerm_public_ip.jenkins.ip_address
}

output "private_ip" {
  description = "Private IP of the Jenkins server."
  value       = azurerm_network_interface.jenkins.private_ip_address
}

output "network_interface_id" {
  description = "ID of the network interface attached to the VM."
  value       = azurerm_network_interface.jenkins.id
}

output "security_group_id" {
  description = "ID of the network security group attached to the NIC."
  value       = azurerm_network_security_group.jenkins.id
}

output "user_assigned_identity_id" {
  description = "ID of the user assigned identity attached to the VM."
  value       = azurerm_user_assigned_identity.jenkins.id
}

output "user_assigned_identity_principal_id" {
  description = "Principal id of the user assigned identity, useful to grant extra roles."
  value       = azurerm_user_assigned_identity.jenkins.principal_id
}

output "admin_username" {
  description = "Admin user used to connect to the VM."
  value       = var.admin_username
}

output "generated_admin_password" {
  description = "Random admin password, only set when no SSH public key is provided."
  value       = var.admin_ssh_public_key == "" ? random_password.vm[0].result : null
  sensitive   = true
}
