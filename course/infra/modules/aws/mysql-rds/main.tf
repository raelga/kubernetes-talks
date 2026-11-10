variable "name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "app_security_group_id" { type = string }
variable "database_instance_class" {
  type    = string
  default = "db.t4g.micro"
}
variable "mysql_engine_version" {
  type    = string
  default = "8.4.11"
}
data "aws_rds_engine_version" "mysql" {
  engine  = "mysql"
  version = var.mysql_engine_version
}
resource "aws_security_group" "database" {
  name        = "${var.name}-database"
  description = "MySQL from WordPress only"
  vpc_id      = var.vpc_id
}
resource "aws_vpc_security_group_ingress_rule" "database" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = var.app_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
}
module "database" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.12.0"

  identifier                  = var.name
  engine                      = "mysql"
  engine_version              = data.aws_rds_engine_version.mysql.version
  instance_class              = var.database_instance_class
  allocated_storage           = 20
  storage_type                = "gp3"
  storage_encrypted           = true
  db_name                     = "wordpress"
  username                    = "labadmin"
  manage_master_user_password = true
  create_db_subnet_group      = true
  subnet_ids                  = var.private_subnet_ids
  vpc_security_group_ids      = [aws_security_group.database.id]
  create_db_parameter_group   = false
  create_db_option_group      = false
  publicly_accessible         = false
  multi_az                    = false
  backup_retention_period     = 0
  deletion_protection         = false
  skip_final_snapshot         = true
  delete_automated_backups    = true
}
resource "aws_secretsmanager_secret" "application" {
  name                    = "${var.name}-wordpress-app"
  recovery_window_in_days = 0
}
resource "random_password" "database" {
  length  = 32
  special = false
}
resource "random_password" "salt" {
  for_each = toset(["AUTH_KEY", "SECURE_AUTH_KEY", "LOGGED_IN_KEY", "NONCE_KEY", "AUTH_SALT", "SECURE_AUTH_SALT", "LOGGED_IN_SALT", "NONCE_SALT"])
  length   = 64
  special  = false
}
resource "aws_secretsmanager_secret_version" "application" {
  secret_id = aws_secretsmanager_secret.application.id
  secret_string = jsonencode({
    username = "wordpress_app"
    password = random_password.database.result
    host     = module.database.db_instance_address
    dbname   = module.database.db_instance_name
    salts    = { for name, value in random_password.salt : name => value.result }
  })
}
output "endpoint" { value = module.database.db_instance_address }
output "security_group_id" { value = aws_security_group.database.id }
output "secret_arn" {
  value      = aws_secretsmanager_secret.application.arn
  depends_on = [aws_secretsmanager_secret_version.application]
}
output "master_secret_arn" { value = module.database.db_instance_master_user_secret_arn }
