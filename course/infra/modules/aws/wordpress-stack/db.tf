data "aws_rds_engine_version" "mysql" {
  engine  = "mysql"
  version = var.mysql_engine_version
}

resource "aws_security_group" "database" {
  name        = "${local.name}-database"
  description = "Private MySQL from the WordPress security group only"
  vpc_id      = aws_vpc.lab.id
  tags        = { Name = "${local.name}-database" }
}

resource "aws_vpc_security_group_ingress_rule" "database" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
}

resource "aws_vpc_security_group_egress_rule" "database" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.database.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
}

resource "aws_db_subnet_group" "app" {
  name       = local.name
  subnet_ids = aws_subnet.private[*].id
  tags       = { Name = local.name }
}

resource "aws_db_instance" "app" {
  identifier                   = local.name
  engine                       = "mysql"
  engine_version               = data.aws_rds_engine_version.mysql.version
  instance_class               = var.database_instance_class
  allocated_storage            = 20
  storage_type                 = "gp3"
  storage_encrypted            = true
  db_name                      = "wordpress"
  username                     = "labadmin"
  manage_master_user_password  = true
  db_subnet_group_name         = aws_db_subnet_group.app.name
  vpc_security_group_ids       = [aws_security_group.database.id]
  publicly_accessible          = false
  multi_az                     = false
  backup_retention_period      = 0
  deletion_protection          = false
  skip_final_snapshot          = true
  delete_automated_backups     = true
  auto_minor_version_upgrade   = true
  copy_tags_to_snapshot        = false
  performance_insights_enabled = false
  tags                         = { Name = local.name }
}
