data "azurerm_client_config" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name = "wp-${random_id.suffix.hex}"
  salts = toset([
    "AUTH_KEY", "SECURE_AUTH_KEY", "LOGGED_IN_KEY", "NONCE_KEY",
    "AUTH_SALT", "SECURE_AUTH_SALT", "LOGGED_IN_SALT", "NONCE_SALT"
  ])
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-${local.name}"
  location = var.location
}

resource "azurerm_virtual_network" "lab" {
  name                = "vnet-${local.name}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.43.0.0/16"]
}

resource "azurerm_subnet" "vm" {
  name                 = "web"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.43.1.0/24"]
}

resource "azurerm_subnet" "mysql" {
  name                 = "mysql"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.43.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "mysql-flexible"
    service_delegation {
      name    = "Microsoft.DBforMySQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_private_dns_zone" "mysql" {
  name                = "${local.name}.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.lab.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = "mysql-link"
  resource_group_name   = azurerm_resource_group.lab.name
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  virtual_network_id    = azurerm_virtual_network.lab.id
}

resource "random_password" "admin" {
  length  = 32
  special = false
}
resource "random_password" "app" {
  length  = 32
  special = false
}
resource "random_password" "salt" {
  for_each = local.salts
  length   = 64
  special  = false
}

resource "azurerm_mysql_flexible_server" "wordpress" {
  name                   = "mysql-${local.name}"
  resource_group_name    = azurerm_resource_group.lab.name
  location               = azurerm_resource_group.lab.location
  administrator_login    = "wpadmin"
  administrator_password = random_password.admin.result
  backup_retention_days  = 7
  delegated_subnet_id    = azurerm_subnet.mysql.id
  private_dns_zone_id    = azurerm_private_dns_zone.mysql.id
  sku_name               = "B_Standard_B1ms"
  version                = "8.0.21"

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]
}

resource "azurerm_user_assigned_identity" "vm" {
  name                = "id-${local.name}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
}

resource "azurerm_key_vault" "lab" {
  name                       = "kv${random_id.suffix.hex}"
  location                   = azurerm_resource_group.lab.location
  resource_group_name        = azurerm_resource_group.lab.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  rbac_authorization_enabled = false
}

resource "azurerm_key_vault_access_policy" "operator" {
  key_vault_id       = azurerm_key_vault.lab.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = data.azurerm_client_config.current.object_id
  secret_permissions = ["Get", "List", "Set", "Delete", "Recover", "Purge"]
}

resource "azurerm_key_vault_access_policy" "vm" {
  key_vault_id       = azurerm_key_vault.lab.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_user_assigned_identity.vm.principal_id
  secret_permissions = ["Get"]
}

resource "azurerm_key_vault_secret" "admin" {
  name         = "db-admin"
  value        = random_password.admin.result
  key_vault_id = azurerm_key_vault.lab.id
  depends_on   = [azurerm_key_vault_access_policy.operator]
}
resource "azurerm_key_vault_secret" "app" {
  name         = "db-app"
  value        = random_password.app.result
  key_vault_id = azurerm_key_vault.lab.id
  depends_on   = [azurerm_key_vault_access_policy.operator]
}
resource "azurerm_key_vault_secret" "salts" {
  name         = "wp-salts"
  value        = jsonencode({ for name, salt in random_password.salt : name => salt.result })
  key_vault_id = azurerm_key_vault.lab.id
  depends_on   = [azurerm_key_vault_access_policy.operator]
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-${local.name}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  security_rule {
    name                       = "http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.admin_cidr
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "ssh"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_cidr
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.vm.id
  network_security_group_id = azurerm_network_security_group.web.id
}
resource "azurerm_public_ip" "web" {
  name                = "pip-${local.name}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  allocation_method   = "Static"
  sku                 = "Standard"
}
resource "azurerm_network_interface" "web" {
  name                = "nic-${local.name}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web.id
  }
}
resource "azurerm_linux_virtual_machine" "web" {
  name                  = "vm-${local.name}"
  resource_group_name   = azurerm_resource_group.lab.name
  location              = azurerm_resource_group.lab.location
  size                  = var.vm_size
  zone                  = var.zone
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.web.id]
  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.vm.id]
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  custom_data = base64encode(templatefile("${path.module}/bootstrap.sh.tftpl", {
    vault_uri          = azurerm_key_vault.lab.vault_uri
    identity_client_id = azurerm_user_assigned_identity.vm.client_id
    db_host            = azurerm_mysql_flexible_server.wordpress.fqdn
  }))
  depends_on = [
    azurerm_key_vault_access_policy.vm,
    azurerm_key_vault_secret.admin,
    azurerm_key_vault_secret.app,
    azurerm_key_vault_secret.salts,
    azurerm_subnet_network_security_group_association.web
  ]
}
