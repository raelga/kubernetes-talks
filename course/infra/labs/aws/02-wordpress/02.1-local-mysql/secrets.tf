resource "random_password" "db" {
  length  = 32
  special = false
}
resource "aws_secretsmanager_secret" "db" {
  name_prefix             = "${local.name}-db-"
  recovery_window_in_days = 0
}
resource "aws_secretsmanager_secret_version" "db" {
  secret_id     = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({ username = "wpadmin", password = random_password.db.result })
}
