
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

resource "azurerm_virtual_machine" "main" {
  name                  = "${random_id.server.hex}-vm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_DS1_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "sandbox"
    admin_username = "azuresandboxuser"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    dynamic "ssh_keys" {
      for_each = var.public_ssh_keys
      content {
        key_data = ssh_keys.value
        path = "home/azuresandboxuser/.ssh/authorized_keys"
      }
    }
  }
  tags = {
    environment = "staging"
  }
}

output "ssh" {
    value = "ssh azuresandboxuser@${azurerm_public_ip.ip.ip_address}"
}