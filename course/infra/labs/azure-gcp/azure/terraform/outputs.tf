output "ownership" {
  value = local.tags
}
output "resource_group" {
  value = azurerm_resource_group.lab.name
}
output "http_url" {
  value = "http://${azurerm_public_ip.lab.ip_address}:8080"
}
output "storage_account" {
  value = azurerm_storage_account.lab.name
}
output "private_container" {
  value = azurerm_storage_container.lab.name
}
output "vm_id" {
  value = azurerm_linux_virtual_machine.lab.id
}
