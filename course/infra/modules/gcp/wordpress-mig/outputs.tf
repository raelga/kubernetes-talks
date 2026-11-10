output "name_prefix" {
  description = "Prefix used to distinguish this stack's resources."
  value       = var.name_prefix
}

output "instance_group_name" {
  description = "Zonal managed instance group manager for the WordPress lab."
  value       = google_compute_instance_group_manager.wordpress.name
}

output "url" {
  description = "Stable HTTP load balancer URL; traffic is not encrypted."
  value       = "http://${google_compute_address.wordpress.address}"
}

output "region" {
  description = "Region of the load balancer and Cloud SQL instance."
  value       = var.region
}

output "zone" {
  description = "Zone of the managed instance group."
  value       = var.zone
}

output "database_private_ip" {
  description = "Private Cloud SQL address, reachable only through the VPC."
  value       = google_sql_database_instance.wordpress.private_ip_address
}
