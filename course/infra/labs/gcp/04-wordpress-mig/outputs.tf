output "name_prefix" {
  description = "Prefix identifying this WordPress stack."
  value       = module.wordpress_mig.name_prefix
}

output "instance_group_name" {
  description = "Zonal managed instance group for WordPress."
  value       = module.wordpress_mig.instance_group_name
}

output "url" {
  description = "HTTP load balancer URL."
  value       = module.wordpress_mig.url
}

output "region" {
  description = "Deployment region."
  value       = module.wordpress_mig.region
}

output "zone" {
  description = "Managed instance group zone."
  value       = module.wordpress_mig.zone
}

output "database_private_ip" {
  description = "Private Cloud SQL address, reachable only through the VPC."
  value       = module.wordpress_mig.database_private_ip
}
