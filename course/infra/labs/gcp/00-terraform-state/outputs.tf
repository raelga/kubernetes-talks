output "state_bucket_name" {
  description = "Bucket name to pass to Terraform backend initialization."
  value       = google_storage_bucket.state.name
}
