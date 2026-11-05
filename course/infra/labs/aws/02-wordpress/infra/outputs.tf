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
  value = aws_iam_role.app.name
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
  value = var.enable_database ? aws_db_instance.app[0].identifier : null
}
output "database_endpoint" {
  description = "Hostname only, without the port; pass to configure.php."
  value       = var.enable_database ? aws_db_instance.app[0].address : null
}
output "database_name" {
  value = var.enable_database ? aws_db_instance.app[0].db_name : null
}
output "database_secret_arn" {
  description = "Master secret identifier, not its value; EC2 reads it only during explicit configuration."
  value       = var.enable_database ? aws_db_instance.app[0].master_user_secret[0].secret_arn : null
}
