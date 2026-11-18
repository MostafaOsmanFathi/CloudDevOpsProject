locals {
  nat_gateway_count = var.single_nat_gateway ? 1 : length(var.availability_zones)
}

# -----------------------------------------------------------------------------
# Virtual network and public subnets
# -----------------------------------------------------------------------------

resource "azurerm_virtual_network" "this" {
  location            = var.location
  name                = "${var.name_prefix}-vnet"
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vnet"
  })
}

# Subnets are named after the availability zone, so the AKS node pools can be
# told which subnet belongs to which zone.
resource "azurerm_subnet" "public" {
  count = length(var.availability_zones)

  name                 = "${var.name_prefix}-public-subnet-${count.index + 1}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.public_subnet_cidrs[count.index]]

  service_endpoints = [
    "Microsoft.ContainerRegistry",
    "Microsoft.Storage",
  ]
}

resource "azurerm_subnet" "private" {
  count = length(var.availability_zones)

  name                 = "${var.name_prefix}-private-subnet-${count.index + 1}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.private_subnet_cidrs[count.index]]

  service_endpoints = [
    "Microsoft.ContainerRegistry",
    "Microsoft.Storage",
  ]
}

# -----------------------------------------------------------------------------
# Network security groups
# Azure NSG rules are stateful, the return traffic of an allowed connection is
# always allowed, unlike the stateless network ACLs on AWS.
# -----------------------------------------------------------------------------

resource "azurerm_network_security_group" "public" {
  location            = var.location
  name                = "${var.name_prefix}-public-nsg"
  resource_group_name = var.resource_group_name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-nsg"
  })
}

resource "azurerm_network_security_rule" "public_admin_ssh" {
  name                        = "AdminSsh"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.public.name
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.admin_cidr
  destination_address_prefix  = "*"
}

resource "azurerm_network_security_rule" "public_http" {
  name                        = "Http"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.public.name
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
}

resource "azurerm_network_security_rule" "public_https" {
  name                        = "Https"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.public.name
  priority                    = 102
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
}

resource "azurerm_network_security_rule" "public_internal" {
  name                        = "VnetInbound"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.public.name
  priority                    = 103
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.vnet_cidr
  destination_address_prefix  = "*"
}

resource "azurerm_network_security_rule" "public_egress" {
  name                        = "EgressAllowAll"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.public.name
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
}

resource "azurerm_subnet_network_security_group_association" "public" {
  count = length(azurerm_subnet.public)

  network_security_group_id = azurerm_network_security_group.public.id
  subnet_id                 = azurerm_subnet.public[count.index].id
}

resource "azurerm_network_security_group" "private" {
  location            = var.location
  name                = "${var.name_prefix}-private-nsg"
  resource_group_name = var.resource_group_name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-nsg"
  })
}

resource "azurerm_network_security_rule" "private_admin_ssh" {
  name                        = "AdminSsh"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.private.name
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.admin_cidr
  destination_address_prefix  = "*"
}

resource "azurerm_network_security_rule" "private_internal" {
  name                        = "VnetInbound"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.private.name
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.vnet_cidr
  destination_address_prefix  = "*"
}

resource "azurerm_network_security_rule" "private_egress" {
  name                        = "EgressAllowAll"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.private.name
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
}

resource "azurerm_subnet_network_security_group_association" "private" {
  count = length(azurerm_subnet.private)

  network_security_group_id = azurerm_network_security_group.private.id
  subnet_id                 = azurerm_subnet.private[count.index].id
}

# -----------------------------------------------------------------------------
# NAT gateway - outbound internet access for the private subnets
# -----------------------------------------------------------------------------

resource "azurerm_public_ip" "nat" {
  count = local.nat_gateway_count

  location            = var.location
  name                = "${var.name_prefix}-nat-ip-${count.index + 1}"
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-ip-${count.index + 1}"
  })
}

resource "azurerm_nat_gateway" "this" {
  count = local.nat_gateway_count

  location            = var.location
  name                = "${var.name_prefix}-nat-${count.index + 1}"
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-${count.index + 1}"
  })
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  count = local.nat_gateway_count

  nat_gateway_id       = azurerm_nat_gateway.this[count.index].id
  public_ip_address_id = azurerm_public_ip.nat[count.index].id
}

resource "azurerm_subnet_nat_gateway_association" "private" {
  count = length(azurerm_subnet.private)

  nat_gateway_id = var.single_nat_gateway ? azurerm_nat_gateway.this[0].id : azurerm_nat_gateway.this[count.index].id
  subnet_id      = azurerm_subnet.private[count.index].id

  depends_on = [azurerm_nat_gateway_public_ip_association.this]
}
