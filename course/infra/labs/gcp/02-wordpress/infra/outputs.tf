output "instance_name" {
  description = "Compute Engine instance for the WordPress lab."
  value       = google_compute_instance.wordpress.name
}

output "instance_public_ip" {
  description = "Public IPv4 address of the VM."
  value       = google_compute_instance.wordpress.network_interface[0].access_config[0].nat_ip
}

output "database_private_ip" {
  description = "Private Cloud SQL address, reachable only through the VPC."
  value       = google_sql_database_instance.wordpress.private_ip_address
}
