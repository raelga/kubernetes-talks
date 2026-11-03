output "state_bucket_name" {
  description = "Dedicated bucket for exercise state; not for bootstrap state."
  value       = awscc_s3_bucket.state.bucket_name
}

output "state_bucket_arn" {
  value = awscc_s3_bucket.state.arn
}

output "versioning_status" {
  value = awscc_s3_bucket.state.versioning_configuration.status
}
