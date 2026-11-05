output "state_bucket_name" {
  description = "Bucket to use for this and subsequent labs' S3 backends."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "Stable AWS resource identifier to compare before and after migration."
  value       = aws_s3_bucket.state.arn
}

output "region" {
  description = "Configured AWS region."
  value       = data.aws_region.current.name
}

output "account_id" {
  description = "Actual AWS account resolved from the configured credentials."
  value       = data.aws_caller_identity.current.account_id
}

output "lab_id" {
  description = "Deployment identifier to recover when resuming this deployment."
  value       = var.lab_id
}