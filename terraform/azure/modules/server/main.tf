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

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-jenkins-ip"
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
    offer     = "ubuntu-24_04-lts"
    sku       = "server-gen2"
    version   = "latest"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-jenkins-server"
    Role = "jenkins"
  })
}
