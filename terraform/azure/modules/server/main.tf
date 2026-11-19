# -----------------------------------------------------------------------------
# Identity used by the VM so it can read the registry without keys
# ---------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "jenkins" {
  location            = var.location
  name                = "${var.name_prefix}-jenkins-identity"
  resource_group_name = var.resource_group_name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-jenkins-identity"
  })
}

resource "azurerm_role_assignment" "acr_pull" {
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.jenkins.principal_id
  scope                = var.acr_id
}

# -----------------------------------------------------------------------------
# Network interface
# -----------------------------------------------------------------------------

resource "azurerm_public_ip" "jenkins" {
  location            = var.location
  name                = "${var.name_prefix}-jenkins-ip"
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"

  # Free Microsoft domain: ivolve.denmarkeast.cloudapp.azure.com. Azure DNS is
  # the Route 53 equivalent, but it only hosts zones for a domain you own, so
  # this label is the no-cost way to get a name for the application.
  domain_name_label = var.jenkins_dns_label

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-jenkins-ip"
  })
}

# Second public IP, only to carry the free Microsoft name for Argo CD:
# ivolve-argocd.<location>.cloudapp.azure.com. It is attached to the same NIC as
# a secondary IP configuration, so nginx answers for it like it does for the
# application address. The region allows 3 public IPs and 2 were in use.
resource "azurerm_public_ip" "argocd" {
  location            = var.location
  name                = "${var.name_prefix}-argocd-ip"
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"

  domain_name_label = var.argocd_dns_label

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-argocd-ip"
  })
}

resource "azurerm_network_interface" "jenkins" {
  location            = var.location
  name                = "${var.name_prefix}-jenkins-nic"
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "${var.name_prefix}-jenkins-ipconfig"
    subnet_id                     = var.public_subnet_ids[0]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jenkins.id
  }

  # Secondary address of the same NIC: the Argo CD name. Azure maps the public
  # IP to this private address, and the guest has to own the address for the
  # mapping to work (see the ivolve-secondary-ip unit installed on the VM).
  # Static so the address survives a redeploy and the unit keeps matching.
  ip_configuration {
    name                          = "${var.name_prefix}-argocd-ipconfig"
    subnet_id                     = var.public_subnet_ids[0]
    private_ip_address            = "10.0.0.5"
    private_ip_address_allocation = "Static"
    public_ip_address_id          = azurerm_public_ip.argocd.id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-jenkins-nic"
  })
}

resource "azurerm_network_security_group" "jenkins" {
  location            = var.location
  name                = "${var.name_prefix}-jenkins-nsg"
  resource_group_name = var.resource_group_name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-jenkins-nsg"
  })
}

resource "azurerm_network_security_rule" "jenkins_ssh" {
  name                        = "JenkinsSsh"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.jenkins.name
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.admin_cidr
  destination_address_prefix  = "*"
}

resource "azurerm_network_security_rule" "jenkins_ui" {
  name                        = "JenkinsUi"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.jenkins.name
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080"
  source_address_prefix       = var.admin_cidr
  destination_address_prefix  = "*"
}

# Port 80 is used by nginx as the public entry point to the application; the
# browser hits the Jenkins VM's public IP and nginx proxies into the cluster.
resource "azurerm_network_security_rule" "jenkins_http" {
  name                        = "JenkinsHttp"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.jenkins.name
  priority                    = 103
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = var.admin_cidr
  destination_address_prefix  = "*"
}

resource "azurerm_network_security_rule" "jenkins_internal" {
  name                        = "VnetInbound"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.jenkins.name
  priority                    = 102
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
}

resource "azurerm_network_security_rule" "jenkins_egress" {
  name                        = "EgressAllowAll"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.jenkins.name
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
}

resource "azurerm_network_interface_security_group_association" "jenkins" {
  network_interface_id      = azurerm_network_interface.jenkins.id
  network_security_group_id = azurerm_network_security_group.jenkins.id
}

# -----------------------------------------------------------------------------
# Virtual machine running Jenkins
# -----------------------------------------------------------------------------

resource "random_password" "vm" {
  count = var.admin_ssh_public_key == "" ? 1 : 0

  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+"
  min_lower        = 4
  min_upper        = 4
  min_numeric      = 4
  min_special      = 4
}

resource "azurerm_linux_virtual_machine" "jenkins" {
  location                        = var.location
  name                            = "${var.name_prefix}-jenkins-server"
  resource_group_name             = var.resource_group_name
  size                            = var.vm_size
  computer_name                   = "${var.name_prefix}-jenkins"
  admin_username                  = var.admin_username
  network_interface_ids           = [azurerm_network_interface.jenkins.id]
  disable_password_authentication = var.admin_ssh_public_key != ""
  admin_password                  = var.admin_ssh_public_key != "" ? null : random_password.vm[0].result

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.jenkins.id]
  }

  dynamic "admin_ssh_key" {
    for_each = var.admin_ssh_public_key != "" ? [1] : []
    content {
      username   = var.admin_username
      public_key = var.admin_ssh_public_key
    }
  }

  os_disk {
    caching              = "ReadWrite"
    disk_size_gb         = var.os_disk_size_gb
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-jenkins-server"
    Role = "jenkins"
  })
}
