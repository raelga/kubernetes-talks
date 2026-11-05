output "ownership" {
  value = local.labels
}
output "project_id" {
  value = var.project_id
}
output "http_url" {
  value = "http://${google_compute_instance.lab.network_interface[0].access_config[0].nat_ip}:8080"
}
output "bucket_name" {
  value = google_storage_bucket.lab.name
}
output "vm_name" {
  value = google_compute_instance.lab.name
}
output "network_name" {
  value = google_compute_network.lab.name
}
