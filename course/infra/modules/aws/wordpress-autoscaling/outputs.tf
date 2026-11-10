output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
output "aws_region" {
  value = data.aws_region.current.name
}
output "lab_id" {
  value = var.lab_id
}
output "ami_id" {
  value = aws_launch_template.app.image_id
}
output "stack_name" {
  value = local.name
}
output "application_url" {
  value = local.tls_enabled ? "https://${var.domain_name}" : "http://${aws_lb.app.dns_name}"
}
output "http_url" {
  value = "http://${aws_lb.app.dns_name}"
}
output "asg_name" {
  value = aws_autoscaling_group.app.name
}
output "vpc_id" {
  value = var.vpc_id
}
output "alb_arn" {
  value = aws_lb.app.arn
}
output "target_group_arn" {
  value = aws_lb_target_group.app.arn
}
output "app_security_group_id" {
  value = var.app_security_group_id
}
output "instance_role_name" {
  value = data.aws_iam_instance_profile.app.role_name
}
output "certificate_arn" {
  value = local.tls_enabled ? aws_acm_certificate.app[0].arn : null
}
output "domain_name" {
  value = var.domain_name
}
output "hosted_zone_id" {
  value = var.hosted_zone_id
}
output "database_endpoint" {
  description = "Private RDS hostname used by WordPress."
  value       = var.database_endpoint
}
output "database_name" {
  value = local.database_name
}
output "database_secret_arn" {
  description = "RDS-managed administrator secret ARN used by EC2 during database bootstrap."
  value       = var.master_secret_arn
}
output "application_secret_arn" {
  description = "Dedicated WordPress database-user secret; no secret value is output."
  value       = aws_secretsmanager_secret.application.arn
}
