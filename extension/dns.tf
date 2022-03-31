

resource "azurerm_resource_group" "dns" {
  name     = "rg-${var.svc_name}-hub-${var.location_code}-001"
  location = var.location
  tags     = var.tags
}

locals {
  zones = ["1", "2", "3"]
}

data "azurerm_virtual_network" "vnet" {
  # uncomment for prototype
  # name                = var.vnet_name
  #resource_group_name = var.vnet_rg_name
  # uncomment below for MVP:
  name                = "vnet-shared-hub-${var.location_code}-001"
  resource_group_name = "rg-shared-hub-${var.location_code}-001"
}

data "azurerm_log_analytics_workspace" "log" {
  name                = "log-shared-prod-${var.location_code}-001"
  resource_group_name = "rg-log-shared-prod-${var.location_code}-001"

}

data "azurerm_subnet" "subnet" {
  # uncomment for prototype
  #virtual_network_name = var.vnet_name
  #name                 = var.subnet_name
  #resource_group_name  = var.vnet_rg_name
  # uncomment below for MVP:
  virtual_network_name = "vnet-shared-hub-${var.location_code}-001"
  name                 = "DNSProxySubnet"
  resource_group_name  = "rg-shared-hub-${var.location_code}-001"
}

resource "random_id" "storage_account" {
  byte_length = 8
}

resource "azurerm_storage_account" "sa1" {
  name                     = "dnsprov${lower(random_id.storage_account.hex)}"
  resource_group_name      = azurerm_resource_group.dns.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  tags                     = var.tags

  lifecycle {
    #ignore_changes = [tags]
    ignore_changes = [tags.FirstApply]
  }
  depends_on = [
    azurerm_resource_group.dns
  ]
}

resource "azurerm_storage_container" "scripts" {
  name                  = "scripts"
  storage_account_name  = azurerm_storage_account.sa1.name
  container_access_type = "private"
  depends_on = [
    azurerm_storage_account.sa1
  ]
}

data "azurerm_storage_account_blob_container_sas" "scripts" {
  connection_string = azurerm_storage_account.sa1.primary_connection_string
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
  connection_string = azurerm_storage_account.sa1.primary_connection_string
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
  storage_account_name   = azurerm_storage_account.sa1.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  content_md5            = filemd5("scripts/ConditionalForwarders.txt")
  source                 = "scripts/ConditionalForwarders.txt"

  depends_on = [
    azurerm_storage_container.scripts
  ]
}

resource "azurerm_storage_blob" "bind_install" {
  name                   = "bind-dns-srv.sh"
  storage_account_name   = azurerm_storage_account.sa1.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  content_md5            = filemd5("scripts/bind-dns-srv.sh")
  source                 = "scripts/bind-dns-srv.sh"

  depends_on = [
    azurerm_storage_container.scripts
  ]
}

resource "azurerm_storage_blob" "fireeye" {
  name                   = "fireyeinstall.sh"
  storage_account_name   = azurerm_storage_account.sa1.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  content_md5            = filemd5("scripts/fireyeinstall.sh")
  source                 = "scripts/fireyeinstall.sh"

  depends_on = [
    azurerm_storage_container.scripts
  ]
}

data "azurerm_key_vault" "hub" {
  count               = var.location_code == "weu" ? 1 : 0
  name                = "kv-shared-hub-${var.location_code}-56d5"
  resource_group_name = "rg-shared-hub-${var.location_code}-001"
}

data "azurerm_key_vault" "hub1" {
  count               = var.location_code == "frc" ? 1 : 0
  name                = "kv-shared-hub-${var.location_code}-6c49"
  resource_group_name = "rg-shared-hub-${var.location_code}-001"
}

# Create TLS Private Key
resource "tls_private_key" "dns" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}
# Store in KV
resource "azurerm_key_vault_secret" "secret" {
  count        = var.location_code == "weu" ? 1 : 0
  name         = "${var.vm_hostname}${var.location_code}-001"
  value        = tls_private_key.dns.private_key_pem
  key_vault_id = data.azurerm_key_vault.hub[0].id
  lifecycle {
    ignore_changes = [

      tags,
    ]
  }

}

resource "azurerm_key_vault_secret" "secret1" {
  count        = var.location_code == "frc" ? 1 : 0
  name         = "${var.vm_hostname}${var.location_code}-001"
  value        = tls_private_key.dns.private_key_pem
  key_vault_id = data.azurerm_key_vault.hub1[0].id

  lifecycle {
    ignore_changes = [

      tags,
    ]
  }

}

resource "azurerm_storage_account" "diags" {
  name                     = "dnsdiags${lower(random_id.storage_account.hex)}"
  resource_group_name      = azurerm_resource_group.dns.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  tags                     = var.tags

  lifecycle {
    ignore_changes = [tags.FirstApply]
    #ignore_changes = [tags]
  }
  depends_on = [
    azurerm_resource_group.dns
  ]
}

resource "azurerm_network_interface" "dns" {
  count               = 2
  name                = "nic-${var.vm_hostname}${var.location_code}${format("%03d", count.index + 1)}"
  location            = var.location
  resource_group_name = azurerm_resource_group.dns.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [
    azurerm_resource_group.dns
  ]

  lifecycle {
    ignore_changes = [

      tags,
    ]
  }
}

resource "azurerm_network_security_group" "dns" {
  name                = "nsg-dnsproxy-shared-hub-${var.location_code}"
  location            = azurerm_resource_group.dns.location
  resource_group_name = azurerm_resource_group.dns.name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "dns-tcp" {
  name                        = "dns-tcp"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.dns.name
  network_security_group_name = azurerm_network_security_group.dns.name
  depends_on = [
    azurerm_network_security_group.dns
  ]
}
resource "azurerm_network_security_rule" "dns-udp" {
  name                        = "dns-udp"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.dns.name
  network_security_group_name = azurerm_network_security_group.dns.name
  depends_on = [
    azurerm_network_security_group.dns
  ]
}
resource "azurerm_network_interface_security_group_association" "dns" {
  count                     = 2
  network_interface_id      = azurerm_network_interface.dns.*.id[count.index]
  network_security_group_id = azurerm_network_security_group.dns.id
  depends_on = [
    azurerm_network_security_group.dns
  ]
}

/*resource "azurerm_marketplace_agreement" "center-for-internet-security-inc" {
  publisher = "center-for-internet-security-inc"
  offer     = "cis-rhel-8-l2"
  plan      = "cis-rhel8-l2"
  lifecycle {
    ignore_changes = [
      publisher,
      offer,
      tags,
      plan
    ]
  }

}*/


resource "azurerm_linux_virtual_machine" "dns" {
  count               = 2
  name                = "${var.vm_hostname}${var.location_code}${format("%03d", count.index + 1)}"
  resource_group_name = azurerm_resource_group.dns.name
  location            = azurerm_resource_group.dns.location
  size                = var.vm_size
  admin_username      = var.admin_username

  #availability_set_id = azurerm_availability_set.dns.id
  zone = count.index + 1
  network_interface_ids = [
    azurerm_network_interface.dns.*.id[count.index],
  ]
  boot_diagnostics {
    storage_account_uri = ""
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "center-for-internet-security-inc"
    offer     = "cis-rhel-8-l2"
    sku       = "cis-rhel8-l2"
    version   = "latest"
  }
  plan {
    name      = "cis-rhel8-l2"
    publisher = "center-for-internet-security-inc"
    product   = "cis-rhel-8-l2"
  }

  tags = var.tags
  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.dns.public_key_openssh
  }
  depends_on = [
    azurerm_resource_group.dns,
    azurerm_network_interface.dns
  ]
}

resource "azurerm_virtual_machine_extension" "dns" {
  count                = 2
  name                 = "dnsConfig"
  virtual_machine_id   = azurerm_linux_virtual_machine.dns.*.id[count.index]
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"
  depends_on = [
    azurerm_linux_virtual_machine.dns,
    azurerm_storage_blob.bind_install,
    azurerm_storage_blob.conditional_forwarders,
    azurerm_virtual_machine_extension.log
  ]

  settings = <<SETTINGS
    {
      "fileUris": [
                   "https://${azurerm_storage_account.sa1.name}.blob.core.windows.net/scripts/bind-dns-srv.sh${data.azurerm_storage_account_sas.sa1.sas}",
                   "https://${azurerm_storage_account.sa1.name}.blob.core.windows.net/scripts/ConditionalForwarders.txt${data.azurerm_storage_account_sas.sa1.sas}"
                ],
      "commandToExecute": "sh bind-dns-srv.sh"
    }
SETTINGS

  lifecycle {
    ignore_changes = [

      tags,
    ]
  }

}

resource "azurerm_virtual_machine_extension" "fireeyeagent" {
  count                = 2
  name                 = "dnsConfig"
  virtual_machine_id   = azurerm_linux_virtual_machine.dns.*.id[count.index]
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"
  depends_on = [
    azurerm_linux_virtual_machine.dns,
    azurerm_storage_blob.bind_install,
    azurerm_storage_blob.conditional_forwarders,
    azurerm_virtual_machine_extension.log,
    azurerm_virtual_machine_extension.dns
  ]

  settings = <<SETTINGS
    {
      "fileUris": [
                   "https://${azurerm_storage_account.sa1.name}.blob.core.windows.net/scripts/fireyeinstall.sh${data.azurerm_storage_account_sas.sa1.sas}"
                ],
      "commandToExecute": "sh fireyeinstall.sh"
    }
SETTINGS

}

resource "azurerm_virtual_machine_extension" "log" {
  count                = 2
  name                 = "OmsAgentForLinux"
  virtual_machine_id   = azurerm_linux_virtual_machine.dns.*.id[count.index]
  publisher            = "Microsoft.EnterpriseCloud.Monitoring"
  type                 = "OmsAgentForLinux"
  type_handler_version = "1.12"


  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
        "workspaceId": "${data.azurerm_log_analytics_workspace.log.workspace_id}"
    }
SETTINGS

  protected_settings = <<PROTECTEDSETTINGS
    {
        "workspaceKey": "${data.azurerm_log_analytics_workspace.log.primary_shared_key}"
    }
PROTECTEDSETTINGS
  lifecycle {
    ignore_changes = [

      tags,
    ]
  }

}

resource "azurerm_virtual_machine_extension" "log1" {
  count                = 2
  name                 = "MicrosoftDefender"
  virtual_machine_id   = azurerm_linux_virtual_machine.dns.*.id[count.index]
  publisher            = "Microsoft.Azure.AzureDefenderForServers"
  type                 = "MDE.Linux"
  type_handler_version = "1.0"


  auto_upgrade_minor_version = false

  settings = <<SETTINGS
    {
        "workspaceId": "${data.azurerm_log_analytics_workspace.log.workspace_id}"
    }
SETTINGS

  protected_settings = <<PROTECTEDSETTINGS
    {
        "workspaceKey": "${data.azurerm_log_analytics_workspace.log.primary_shared_key}"
    }
PROTECTEDSETTINGS
  lifecycle {
    ignore_changes = [

      tags,
    ]
  }

}