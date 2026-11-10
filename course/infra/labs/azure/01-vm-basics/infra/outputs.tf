output "vm_name" {
  value = azurerm_linux_virtual_machine.lab.name
}

output "public_ip" {
  value = azurerm_public_ip.lab.ip_address
}

output "application_url" {
  value = "http://${azurerm_public_ip.lab.ip_address}:8080/"
}
