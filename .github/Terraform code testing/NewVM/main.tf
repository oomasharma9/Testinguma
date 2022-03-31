provider "azurerm" {
  features {}
}

resource "random_pet" "rg-name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  name     = random_pet.rg-name.id
  location = var.resource_group_location
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/17"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
#resource "azurerm_public_ip" "myterraformpublicip" {
# name                = "myPublicIP"
#location            = azurerm_resource_group.rg.location
#resource_group_name = azurerm_resource_group.rg.name
#allocation_method   = "Dynamic"}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
  name                = "myNetworkSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
  name                = "myNIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = azurerm_subnet.myterraformsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.myterraformnic.id
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
  name                     = "diag${random_id.randomId.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
# Store in KV
resource "azurerm_key_vault_secret" "secret" {
  count        = 1
  name         = "KVSecret"
  value        = tls_private_key.dns.private_key_pem
  key_vault_id = data.azurerm_key_vault.myterraformkv.id
  }
resource "azurerm_storage_container" "scripts" {
  name                  = "myterraforscripts"
  storage_account_name  = azurerm_storage_account.mystorageaccount.name
  container_access_type = "private"
  depends_on = [
    azurerm_storage_account.mystorageaccount
  ]
}
data "azurerm_storage_account_blob_container_sas" "scripts" {
  connection_string = azurerm_storage_account.mystorageaccount.primary_connection_string
  container_name    = azurerm_storage_container.scripts.name
  https_only        = true
  start             = timeadd(timestamp(), "-20m")
  expiry            = timeadd(timestamp(), "240m")

  permissions {
    read   = true
    add    = true
    create = false
    write  = false
    delete = true
    list   = true
  }
}

data "azurerm_storage_account_sas" "sa1" {
  connection_string = azurerm_storage_account.mystorageaccount.primary_connection_string
  https_only        = true
  signed_version    = "2020-08-04"

  resource_types {
    service   = true
    container = true
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start  = timestamp()
  expiry = timeadd(timestamp(), "240m")

  permissions {
    read    = true
    write   = true
    delete  = false
    list    = false
    add     = true
    create  = true
    update  = false
    process = false
  }
}
resource "azurerm_storage_blob" "conditional_forwarders" {
  name                   = "ConditionalForwarders.txt"
  storage_account_name   = azurerm_storage_account.mystorageaccount.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  content_md5            = filemd5("scripts/ConditionalForwarders.txt")
  source                 = "scripts/ConditionalForwarders.txt"

  depends_on = [
    azurerm_storage_container.scripts
  ]
}
resource "azurerm_storage_blob" "fireeye" {
  name                   = "fireyeinstall.sh"
  storage_account_name   = azurerm_storage_account.mystorageaccount.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  content_md5            = filemd5("scripts/fireyeinstall.sh")
  source                 = "scripts/fireyeinstall.sh"

  depends_on = [
    azurerm_storage_container.scripts
  ]
}
data "azurerm_key_vault" "hub" {
  location            = azurerm_resource_group.rg.location
  name                = "myterraformkv"
  resource_group_name = "azurerm_resource_group.rg.name"
}
# Create virtual machine
resource "azurerm_linux_virtual_machine" "myterraformvm" {
  name                  = "myVM"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.myterraformnic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name                   = "myvm"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.example_ssh.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
  }
  data "azurerm_log_analytics_workspace" "log" {
    name                = "myterraformlaw"
    resource_group_name = "azurerm_resource_group.rg.name"
  }
  resource "azurerm_virtual_machine_extension" "vmextension" {
  count                = 1
  name                 = "myterraformextension"
  virtual_machine_id   = azurerm_linux_virtual_machine.myterraformvm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"
  depends_on = [
    azurerm_linux_virtual_machine.myterraformvm,
    azurerm_storage_blob.conditional_forwarders,
    azurerm_virtual_machine_extension.log
  ]

  settings = <<SETTINGS
    {
      "fileUris": [
                   "https://${azurerm_storage_account.mystorageaccount.name}.blob.core.windows.net/scripts/ConditionalForwarders.txt${data.azurerm_storage_account_sas.mystorageaccount.sas}"
                ],
      "commandToExecute": "sh fireyeinstall.sh"
    }
SETTINGS
}
}