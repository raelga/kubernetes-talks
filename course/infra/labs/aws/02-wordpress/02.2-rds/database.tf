resource "aws_db_subnet_group" "wordpress" {
  name_prefix = "${local.name}-"
  subnet_ids  = [aws_subnet.database_a.id, aws_subnet.database_b.id]
}
resource "aws_security_group" "database" {
  name_prefix = "${local.name}-db-"
  vpc_id      = aws_vpc.lab.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }
}
resource "aws_db_instance" "wordpress" {
  identifier_prefix        = "${local.name}-"
  engine                   = "mysql"
  instance_class           = var.database_instance_class
  allocated_storage        = 20
  storage_type             = "gp3"
  storage_encrypted        = true
  db_name                  = "wordpress"
  username                 = "wpadmin"
  password                 = random_password.db.result
  db_subnet_group_name     = aws_db_subnet_group.wordpress.name
  vpc_security_group_ids   = [aws_security_group.database.id]
  publicly_accessible      = false
  multi_az                 = false
  backup_retention_period  = 0
  deletion_protection      = false
  skip_final_snapshot      = true
  delete_automated_backups = true
}
