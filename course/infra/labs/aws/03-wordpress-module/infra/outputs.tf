output "account_id" {
  value = module.wordpress_stack.account_id
}

output "aws_region" {
  value = module.wordpress_stack.aws_region
}

output "lab_id" {
  value = module.wordpress_stack.lab_id
}

output "ami_id" {
  value = module.wordpress_stack.ami_id
}

output "stack_name" {
  value = module.wordpress_stack.stack_name
}

output "application_url" {
  value = module.wordpress_stack.application_url
}

output "http_url" {
  value = module.wordpress_stack.http_url
}

output "instance_id" {
  value = module.wordpress_stack.instance_id
}

output "instance_private_ip" {
  value = module.wordpress_stack.instance_private_ip
}

output "ssm_start_session_command" {
  value = module.wordpress_stack.ssm_start_session_command
}

output "vpc_id" {
  value = module.wordpress_stack.vpc_id
}

output "nat_gateway_id" {
  value = module.wordpress_stack.nat_gateway_id
}

output "nat_eip_allocation_id" {
  value = module.wordpress_stack.nat_eip_allocation_id
}

output "alb_arn" {
  value = module.wordpress_stack.alb_arn
}

output "target_group_arn" {
  value = module.wordpress_stack.target_group_arn
}

output "app_security_group_id" {
  value = module.wordpress_stack.app_security_group_id
}

output "instance_role_name" {
  value = module.wordpress_stack.instance_role_name
}

output "certificate_arn" {
  value = module.wordpress_stack.certificate_arn
}

output "domain_name" {
  value = module.wordpress_stack.domain_name
}

output "hosted_zone_id" {
  value = module.wordpress_stack.hosted_zone_id
}

output "database_identifier" {
  value = module.wordpress_stack.database_identifier
}

output "database_endpoint" {
  value = module.wordpress_stack.database_endpoint
}

output "database_name" {
  value = module.wordpress_stack.database_name
}

output "database_secret_arn" {
  value = module.wordpress_stack.database_secret_arn
}

output "application_secret_arn" {
  value = module.wordpress_stack.application_secret_arn
}
