output "instance_name" {
  value = google_compute_instance.lab.name
}

output "zone" {
  value = google_compute_instance.lab.zone
}

output "public_ip" {
  value = google_compute_instance.lab.network_interface[0].access_config[0].nat_ip
}

output "application_url" {
  value = "http://${google_compute_instance.lab.network_interface[0].access_config[0].nat_ip}:8080/"
}
