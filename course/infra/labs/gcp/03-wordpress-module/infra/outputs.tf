output "name_prefix" {
  description = "Prefix identifying this WordPress stack."
  value       = module.wordpress_stack.name_prefix
}

output "instance_name" {
  description = "Compute Engine instance for the WordPress module lab."
  value       = module.wordpress_stack.instance_name
}

output "instance_public_ip" {
  description = "Public IPv4 address of the VM."
  value       = module.wordpress_stack.instance_public_ip
}

output "database_private_ip" {
  description = "Private Cloud SQL address, reachable only through the VPC."
  value       = module.wordpress_stack.database_private_ip
}
