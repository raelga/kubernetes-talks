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
  value = aws_instance.app.ami
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
output "instance_id" {
  value = aws_instance.app.id
}
output "instance_private_ip" {
  value = aws_instance.app.private_ip
}
output "ssm_start_session_command" {
  value = "aws ssm start-session --region ${data.aws_region.current.name} --target ${aws_instance.app.id}"
}
output "vpc_id" {
  value = aws_vpc.lab.id
}
output "nat_gateway_id" {
  value = aws_nat_gateway.lab.id
}
output "nat_eip_allocation_id" {
  value = aws_eip.nat.id
}
output "alb_arn" {
  value = aws_lb.app.arn
}
output "target_group_arn" {
  value = aws_lb_target_group.app.arn
}
output "app_security_group_id" {
  value = aws_security_group.app.id
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
output "database_identifier" {
  value = aws_db_instance.app.identifier
}
output "database_endpoint" {
  description = "Private RDS hostname used by WordPress."
  value       = aws_db_instance.app.address
}
output "database_name" {
  value = aws_db_instance.app.db_name
}
output "database_secret_arn" {
  description = "RDS-managed administrator secret ARN used by EC2 during database bootstrap."
  value       = aws_db_instance.app.master_user_secret[0].secret_arn
}
output "application_secret_arn" {
  description = "Dedicated WordPress database-user secret; no secret value is output."
  value       = aws_secretsmanager_secret.application.arn
}
