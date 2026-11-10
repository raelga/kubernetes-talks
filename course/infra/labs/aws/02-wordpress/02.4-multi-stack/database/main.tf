variable "state_bucket" { type = string }
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "wordpress/network/terraform.tfstate"
    region = var.aws_region
  }
}
variable "name" {
  type    = string
  default = "wp-split"
}
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
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
}
resource "aws_vpc_security_group_ingress_rule" "database" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = data.terraform_remote_state.network.outputs.app_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
}
resource "aws_db_subnet_group" "app" {
  name       = var.name
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
}
resource "aws_db_instance" "app" {
  identifier                  = var.name
  engine                      = "mysql"
  engine_version              = data.aws_rds_engine_version.mysql.version
  instance_class              = var.database_instance_class
  allocated_storage           = 20
  storage_type                = "gp3"
  storage_encrypted           = true
  username                    = "labadmin"
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.app.name
  vpc_security_group_ids      = [aws_security_group.database.id]
  publicly_accessible         = false
  multi_az                    = false
  backup_retention_period     = 0
  deletion_protection         = false
  skip_final_snapshot         = true
  delete_automated_backups    = true
}
output "endpoint" { value = aws_db_instance.app.address }
output "security_group_id" { value = aws_security_group.database.id }
output "master_secret_arn" { value = aws_db_instance.app.master_user_secret[0].secret_arn }
