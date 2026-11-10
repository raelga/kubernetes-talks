data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-arm64"]
  }
  filter {
    name   = "architecture"
    values = ["arm64"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}
resource "aws_instance" "wordpress" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = var.instance_profile_name
  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/bootstrap.sh.tftpl", {
    region            = var.aws_region
    secret_arn        = aws_secretsmanager_secret.db.arn
    db_host           = aws_db_instance.wordpress.address
    local_db          = "false"
    wordpress_version = var.wordpress_version
    wordpress_sha256  = var.wordpress_sha256
  })
  metadata_options {
    http_tokens = "required"
  }
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }
  tags       = { Name = local.name }
  depends_on = [aws_route_table_association.public, aws_secretsmanager_secret_version.db]
}
locals { name = "wp-rds-single" }
