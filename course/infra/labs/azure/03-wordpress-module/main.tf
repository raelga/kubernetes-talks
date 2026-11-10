module "wordpress_stack" {
  source = "../../../modules/azure/wordpress-stack"

  location       = var.location
  ssh_public_key = var.ssh_public_key
  admin_cidr     = var.admin_cidr
  vm_size        = var.vm_size
}

output "wordpress_url" {
  value = module.wordpress_stack.wordpress_url
}

output "ssh_command" {
  value = module.wordpress_stack.ssh_command
}

output "mysql_fqdn" {
  value = module.wordpress_stack.mysql_fqdn
}

output "resource_group" {
  value = module.wordpress_stack.resource_group
}
