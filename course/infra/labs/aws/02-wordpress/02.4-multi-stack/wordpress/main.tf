variable "state_bucket" { type = string }
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "wordpress/network/terraform.tfstate"
    region = var.aws_region
  }
}
data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "wordpress/database/terraform.tfstate"
    region = var.aws_region
  }
}
variable "name" {
  type    = string
  default = "wp-split"
}
variable "instance_profile_name" {
  type    = string
  default = "LabInstanceProfile"
}
variable "instance_type" {
  type    = string
  default = "t4g.small"
}
variable "wordpress_version" {
  type    = string
  default = "7.1.4"
}
variable "wordpress_sha256" {
  type    = string
  default = "881e53a4681ff2cd911651b11cccdede5ae477ddf0765af5d6a1a8b219a1d835"
}
data "aws_region" "current" {}
data "aws_iam_instance_profile" "app" { name = var.instance_profile_name }
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
    name   = "virtualization-type"
    values = ["hvm"]
  }
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
    username = "wp_split_app"
    password = random_password.database.result
    host     = data.terraform_remote_state.database.outputs.endpoint
    dbname   = "wp_split"
    salts    = { for name, value in random_password.salt : name => value.result }
  })
}

locals {
  fetch_credentials = templatefile("${path.module}/bootstrap-credentials.py.tftpl", {
    secret_arn       = aws_secretsmanager_secret.application.arn
    admin_secret_arn = data.terraform_remote_state.database.outputs.master_secret_arn
    region           = data.aws_region.current.name
  })
  install_script = templatefile("${path.module}/install.sh", {
    wordpress_version = var.wordpress_version
    wordpress_sha256  = var.wordpress_sha256
    fetch_credentials = local.fetch_credentials
    wordpress_config  = file("${path.module}/wp-config.php.tftpl")
  })
  user_data_script = templatefile("${path.module}/user-data.sh.tftpl", { installer = local.install_script })
}
resource "aws_instance" "app" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = data.terraform_remote_state.network.outputs.public_subnet_ids[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [data.terraform_remote_state.network.outputs.app_security_group_id]
  iam_instance_profile        = data.aws_iam_instance_profile.app.name
  user_data                   = local.user_data_script
  user_data_replace_on_change = true
  depends_on                  = [aws_secretsmanager_secret_version.application]
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }
  tags = { Name = var.name }
}
output "public_ip" { value = aws_instance.app.public_ip }
output "url" { value = "http://${aws_instance.app.public_ip}/" }
