output "wordpress_url" {
  description = "HTTP lab URL, reachable only from admin_cidr."
  value       = "http://${azurerm_public_ip.web.ip_address}/"
}

output "ssh_command" {
  value = "ssh azureuser@${azurerm_public_ip.web.ip_address}"
}

output "mysql_fqdn" {
  description = "Private MySQL endpoint, resolvable from the lab VNet."
  value       = azurerm_mysql_flexible_server.wordpress.fqdn
}

output "resource_group" {
  value = azurerm_resource_group.lab.name
}
