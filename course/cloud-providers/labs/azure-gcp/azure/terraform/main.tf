terraform {
  required_version = ">= 1.6, < 2.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.0, < 5.0" }
    random  = { source = "hashicorp/random", version = ">= 3.6, < 4.0" }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
  storage_use_azuread             = true
  features {}
}

locals {
  prefix = "upc-2026-cloud-03-${var.lab_id}"
  tags   = { course = "upc-2026", lab = "cloud-03", lab_id = var.lab_id }
}

resource "azurerm_resource_group" "lab" {
  name     = local.prefix
  location = var.location
  tags     = local.tags
}
resource "azurerm_virtual_network" "lab" {
  name                = "${local.prefix}-vnet"
  address_space       = ["10.43.0.0/16"]
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}
resource "azurerm_subnet" "lab" {
  name                 = "app"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.43.1.0/24"]
}
resource "azurerm_network_security_group" "lab" {
  name                = "${local.prefix}-nsg"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
  security_rule {
    name                       = "HTTP-docente"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = var.http_client_cidr
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "Denegar-otra-entrada"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_public_ip" "lab" {
  name                = "${local.prefix}-ip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}
resource "azurerm_network_interface" "lab" {
  name                = "${local.prefix}-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
  ip_configuration {
    name                          = "app"
    subnet_id                     = azurerm_subnet.lab.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lab.id
  }
}
resource "azurerm_network_interface_security_group_association" "lab" {
  network_interface_id      = azurerm_network_interface.lab.id
  network_security_group_id = azurerm_network_security_group.lab.id
}
resource "azurerm_linux_virtual_machine" "lab" {
  name                            = "${local.prefix}-vm"
  location                        = azurerm_resource_group.lab.location
  resource_group_name             = azurerm_resource_group.lab.name
  size                            = var.vm_size
  admin_username                  = "upclab"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.lab.id]
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
    lab_id     = var.lab_id
    app_source = file("${path.module}/../../app.py")
  }))
  tags = local.tags
  admin_ssh_key {
    username   = "upclab"
    public_key = file(pathexpand(var.ssh_public_key_path))
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
  depends_on = [azurerm_network_interface_security_group_association.lab]
}

resource "random_id" "storage" {
  count       = var.storage_account_name == null ? 1 : 0
  byte_length = 4
}

resource "azurerm_storage_account" "lab" {
  name                            = var.storage_account_name != null ? var.storage_account_name : "upc3${replace(var.lab_id, "-", "")}${random_id.storage[0].hex}"
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  tags                            = local.tags
  blob_properties {
    delete_retention_policy { days = 7 }
    container_delete_retention_policy { days = 7 }
  }
}
resource "azurerm_storage_container" "lab" {
  name                  = "private"
  storage_account_id    = azurerm_storage_account.lab.id
  container_access_type = "private"
}
