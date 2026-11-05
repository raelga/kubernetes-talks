output "state_bucket_name" {
  description = "Bucket to use in backend.hcl for this and subsequent labs."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "Stable AWS resource identifier to compare before and after migration."
  value       = aws_s3_bucket.state.arn
}

output "region" {
  description = "Configured AWS region."
  value       = var.region
}
