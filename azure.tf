provider "azurerm" {
  features {}
}

terraform {}

resource "azurerm_resource_group" "learn_vpn_rg" {
  name     = "learn_vpn_rg"
  location = "westus2"
}

### Network


resource "azurerm_virtual_network" "learn_vpn_vnet" {
  name                = "learn_vpn_vnet"
  location            = azurerm_resource_group.learn_vpn_rg.location
  resource_group_name = azurerm_resource_group.learn_vpn_rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "learn_vpn_subnet" {
  name                 = "learn_vpn_subnet"
  resource_group_name  = azurerm_resource_group.learn_vpn_rg.name
  virtual_network_name = azurerm_virtual_network.learn_vpn_vnet.name
  address_prefixes      = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "learn_vpn_gwsubnet" {

  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.learn_vpn_rg.name
  virtual_network_name = azurerm_virtual_network.learn_vpn_vnet.name
  address_prefixes       = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "learn_vpn_publicip" {
  name                = "learn_vpn_publicip"
  location            = azurerm_resource_group.learn_vpn_rg.location
  resource_group_name = azurerm_resource_group.learn_vpn_rg.name


  allocation_method = "Dynamic"
}



resource "azurerm_public_ip" "learn_vpn_vm-publicip" {
  name                = "learn_vpn_public_ip_vm"
  location            = azurerm_resource_group.learn_vpn_rg.location
  resource_group_name = azurerm_resource_group.learn_vpn_rg.name

  allocation_method = "Static"
}

resource "azurerm_network_interface" "learn_vpn_vm-int" {
  name                = "network_interface_vm"
  location            = azurerm_resource_group.learn_vpn_rg.location
  resource_group_name = azurerm_resource_group.learn_vpn_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.learn_vpn_gwsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.learn_vpn_vm-publicip.id
  }
}

data "template_file" "script" {
  template = "${file("./scripts/backend_hashicups.yaml")}"
}

data "template_cloudinit_config" "backend" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = data.template_file.script.rendered
  }
}

resource "azurerm_linux_virtual_machine" "learn_vpn_vm" {
  name                = "vm"
  location            = azurerm_resource_group.learn_vpn_rg.location
  resource_group_name = azurerm_resource_group.learn_vpn_rg.name
  size                = "Standard_F2"
  admin_username      = "ubuntu"
  admin_password = "Plankton123!"

  network_interface_ids = [
    azurerm_network_interface.learn_vpn_vm-int.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  custom_data = data.template_cloudinit_config.backend.rendered

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  disable_password_authentication = false

}

### Outputs

output "azure_vm_public_ip" {
  value = azurerm_linux_virtual_machine.learn_vpn_vm.public_ip_address
}

output "azure_vm_private_ip" {
  value = azurerm_linux_virtual_machine.learn_vpn_vm.private_ip_address
}
