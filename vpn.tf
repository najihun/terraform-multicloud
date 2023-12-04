
resource "azurerm_local_network_gateway" "learn_vpn_lngw" {
  name                = "learn_vpn_lngw"
  location            = azurerm_resource_group.learn_vpn_rg.location
  resource_group_name = azurerm_resource_group.learn_vpn_rg.name

  gateway_address = aws_vpn_connection.learn_vpn_connection.tunnel1_address

  address_space = [
    aws_vpc.learn_vpn_vpc.cidr_block
  ]
}

resource "azurerm_virtual_network_gateway_connection" "learn_vpn_vngwc" {
  name                = "learn_vpn_vngwc"
  location            = azurerm_resource_group.learn_vpn_rg.location
  resource_group_name = azurerm_resource_group.learn_vpn_rg.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.learn_vpn_vng.id
  local_network_gateway_id   = azurerm_local_network_gateway.learn_vpn_lngw.id

  shared_key = aws_vpn_connection.learn_vpn_connection.tunnel1_preshared_key
}


resource "azurerm_virtual_network_gateway" "learn_vpn_vng" {
  name                = "learn_vpn_vng"
  location            = azurerm_resource_group.learn_vpn_rg.location
  resource_group_name = azurerm_resource_group.learn_vpn_rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = true
  sku = "VpnGw1"

  ip_configuration {
    name                          = azurerm_public_ip.learn_vpn_publicip.name
    public_ip_address_id          = azurerm_public_ip.learn_vpn_publicip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.learn_vpn_subnet.id
  }
}

resource "aws_vpn_gateway" "learn_vpn_vpngw" {
  vpc_id = aws_vpc.learn_vpn_vpc.id

  tags = {
    Name = "vpn_gateway"
  }
}

resource "aws_vpn_connection" "learn_vpn_connection" {
  vpn_gateway_id      = aws_vpn_gateway.learn_vpn_vpngw.id
  customer_gateway_id = aws_customer_gateway.learn_vpn_cgw.id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = {
    Name = "vpn_connection_1"
  }
}


resource "aws_vpn_connection_route" "learn_vpn_connectionroute" {
  destination_cidr_block = azurerm_virtual_network.learn_vpn_vnet.address_space[0]
  vpn_connection_id      = aws_vpn_connection.learn_vpn_connection.id
}


resource "aws_route" "learn_vpn_az_route" {
  route_table_id = aws_route_table.learn_vpn_rt.id

  destination_cidr_block = azurerm_virtual_network.learn_vpn_vnet.address_space[0]
  gateway_id             = aws_vpn_gateway.learn_vpn_vpngw.id
}

data "azurerm_public_ip" "learn_vpn_az_public_ip" {
  name                = "${azurerm_virtual_network_gateway.learn_vpn_vng.name}_public_ip_1"
  resource_group_name = azurerm_resource_group.learn_vpn_rg.name
}

resource "aws_customer_gateway" "learn_vpn_cgw" {
  bgp_asn = 65000

  ip_address = data.azurerm_public_ip.learn_vpn_az_public_ip.ip_address
  type       = "ipsec.1"

  tags = {
    Name = "customer_gateway_1"
  }
}
