# Provider configuration
provider "azurerm" {
  features {}
}

# Resource group
resource "azurerm_resource_group" "prod" {
  name     = "wordpress_group"
  location = "eastus2"
}

# Virtual network
resource "azurerm_virtual_network" "wordpress-network" {
  name                = "int-net"
  location            = azurerm_resource_group.prod.location
  resource_group_name = azurerm_resource_group.prod.name
  address_space       = ["10.0.0.0/16"]
}

# Subnets
resource "azurerm_subnet" "public_subnet" {
  name                 = "public-sub"
  resource_group_name  = azurerm_resource_group.prod.name
  virtual_network_name = azurerm_virtual_network.wordpress-network.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "private_subnet" {
  name                 = "private-sub"
  resource_group_name  = azurerm_resource_group.prod.name
  virtual_network_name = azurerm_virtual_network.wordpress-network.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_storage_account" "wordpress-storage29876" {
  name                     = "pwstr29876"
  resource_group_name      = azurerm_resource_group.prod.name
  location                 = azurerm_resource_group.prod.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_mssql_server" "wordpress1sql29876" {
  name                         = "wordpress-server29876"
  resource_group_name          = azurerm_resource_group.prod.name
  location                     = azurerm_resource_group.prod.location
  version                      = "12.0"
  administrator_login          = "adminuser"
  administrator_login_password = "@DminP@ssw0rd1"
  public_network_access_enabled = false
}

resource "azurerm_mssql_database" "wordpresmsqldbdb29876" {
  name           = "wordpress-db"
  server_id      = azurerm_mssql_server.wordpress1sql29876.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 10
  read_scale     = true
  sku_name       = "S0"
  zone_redundant = true
} 


resource "azurerm_network_security_group" "nsg" {
  name                = "wordpress-nsg"
  location            = azurerm_resource_group.prod.location
  resource_group_name = azurerm_resource_group.prod.name

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg-aso" {
  subnet_id                 = azurerm_subnet.private_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "wordpress-ip" {
  name                = "public-ip"
  location            = azurerm_resource_group.prod.location
  resource_group_name = azurerm_resource_group.prod.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "wordpress-nic" {
  name                      = "nic"
  location                  = azurerm_resource_group.prod.location
  resource_group_name       = azurerm_resource_group.prod.name
  enable_ip_forwarding      = true
  enable_accelerated_networking = true

  ip_configuration {
    name                          = "ip-config"
    subnet_id                     = azurerm_subnet.public_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.wordpress-ip.id
  }
}

resource "azurerm_virtual_machine" "wordpress-vm" {
  name                  = "wordpress-vm"
  location              = azurerm_resource_group.prod.location
  resource_group_name   = azurerm_resource_group.prod.name
  network_interface_ids = [azurerm_network_interface.wordpress-nic.id]
  vm_size               = "Standard_DS2_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
    disk_size_gb      = 30
  }

  os_profile {
    computer_name  = "vm"
    admin_username = "adminuser"
    admin_password = "@DminP@ssw0rd1"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
  
  tags = {
    envirnoment = "Production"
  }
}
