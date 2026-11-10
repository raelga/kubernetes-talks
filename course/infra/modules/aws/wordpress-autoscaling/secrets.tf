resource "aws_secretsmanager_secret" "application" {
  name                    = "${local.name}-wordpress-app"
  description             = "WordPress database credentials and authentication salts."
  recovery_window_in_days = 0
  tags                    = { Name = "${local.name}-wordpress-app" }
}

resource "random_password" "database" {
  length  = 32
  special = false
}

resource "random_password" "salt" {
  for_each = toset([
    "AUTH_KEY", "SECURE_AUTH_KEY", "LOGGED_IN_KEY", "NONCE_KEY",
    "AUTH_SALT", "SECURE_AUTH_SALT", "LOGGED_IN_SALT", "NONCE_SALT",
  ])
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret_version" "application" {
  secret_id = aws_secretsmanager_secret.application.id
  secret_string = jsonencode({
    username = local.database_user
    password = random_password.database.result
    host     = var.database_endpoint
    dbname   = local.database_name
    salts    = { for name, value in random_password.salt : name => value.result }
  })
}
