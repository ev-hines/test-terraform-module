
variable "region" {
  type = string
}

variable "public_ssh_keys" {
  type = set(string)
}

resource "random_id" "server" {
  byte_length = 8
}


resource "azurerm_resource_group" "rg" {
  name     = "${random_id.server.hex}-resources"
  location = var.region
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${random_id.server.hex}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "ip" {
  name                = "${random_id.server.hex}-ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "${random_id.server.hex}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip.id
  }
}


resource "azurerm_linux_virtual_machine" "example" {
  name                =  "${random_id.server.hex}-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_F2"
  admin_username      = "azure_sandbox_admin"
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  dynamic "admin_ssh_key" {
      for_each = var.public_ssh_keys
      content {
        public_key = admin_ssh_key.value
        username = "azure_sandbox_admin"
      }
    }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

output "ssh" {
    value = "ssh azuresandboxuser@${azurerm_public_ip.ip.ip_address}"
}