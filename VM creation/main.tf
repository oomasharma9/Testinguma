data "azurerm_resource_group" "rg" {
  name = var.rg_name
}

data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = var.rg_name
}

data "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.rg_name
}

resource "azurerm_network_interface" "nic" {
  name                = var.nic_name
  location            = var.location
  resource_group_name = var.rg_name
  delete              = "true"

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = var.rg_name
  tags                = var.tags

  security_rule {
    name      = "AllowSSHfromBastion"
    priority  = 100
    direction = "Inbound"
    access    = "Allow"
    protocol  = "Tcp"

    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.0.0/24"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsgaccociation" {
  subnet_id                 = data.azurerm_subnet.subnet.id
  network_interface_ids     = data.azurerm_network_interface.nic.id
  network_security_group_id = data.azurerm_network_security_group.nsg.id
}

resource "tls_private_key" "privatekey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                            = "testvm"
  location                        = var.location
  resource_group_name             = var.rg_name
  size                            = var.vm_size
  admin_username                  = "testuser"
  admin_password                  = "Test@ccount01"
  disable_password_authentication = true
  delete_os_disk_on_termination   = "true"
  network_interface_ids           = [azurerm_network_interface.nic.id]
  tags                            = var.tags

  os_disk {
    name                 = data.azurerm_windows_virtual_machine.name
    computer_name        = data.azurerm_linux_virtual_machine.name
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    admin_username       = "r7admin"
  }

  source_image_reference {
    publisher = "rapid7"
    offer     = "nexpose-scan-engine"
    sku       = "nexpose-scan-engine"
    version   = "latest"
  }

  plan {
    name      = "nexpose-scan-engine"
    publisher = "rapid7"
    product   = "nexpose-scan-engine"
  }

  boot_diagnostics {
    enabled = "true"
  }

  output "output" {
    value = data.azurerm_linux_virtual_machine.admin_username
  }
}
