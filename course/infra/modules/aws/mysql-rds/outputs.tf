output "endpoint" { value = module.database.db_instance_address }
output "security_group_id" { value = aws_security_group.database.id }
output "secret_arn" {
  value      = aws_secretsmanager_secret.application.arn
  depends_on = [aws_secretsmanager_secret_version.application]
}
output "master_secret_arn" { value = module.database.db_instance_master_user_secret_arn }
