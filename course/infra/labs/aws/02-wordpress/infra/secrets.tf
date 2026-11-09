resource "aws_secretsmanager_secret" "application" {
  name                    = "${local.name}-wordpress-app"
  description             = "WordPress database credentials; value initialized by deploy.sh outside Terraform state."
  recovery_window_in_days = 0
  tags                    = { Name = "${local.name}-wordpress-app" }
}
