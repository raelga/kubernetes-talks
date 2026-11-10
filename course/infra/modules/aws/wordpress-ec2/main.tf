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
resource "aws_eip" "app" {
  domain = "vpc"
  tags   = { Name = var.name }
}

locals {
  fetch_credentials = templatefile("${path.module}/bootstrap-credentials.py.tftpl", {
    secret_arn       = var.secret_arn
    admin_secret_arn = var.master_secret_arn
    region           = data.aws_region.current.name
  })
  install_script = templatefile("${path.module}/install.sh", {
    wordpress_version = var.wordpress_version
    wordpress_sha256  = var.wordpress_sha256
    fetch_credentials = local.fetch_credentials
    wordpress_config  = templatefile("${path.module}/wp-config.php.tftpl", { public_ip = aws_eip.app.public_ip })
  })
  user_data_script = templatefile("${path.module}/user-data.sh.tftpl", { installer = local.install_script })
}
resource "aws_instance" "app" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [var.app_security_group_id, var.ssh_security_group_id]
  iam_instance_profile        = data.aws_iam_instance_profile.app.name
  key_name                    = var.ssh_key_name
  user_data                   = local.user_data_script
  user_data_replace_on_change = true
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
resource "aws_eip_association" "app" {
  instance_id   = aws_instance.app.id
  allocation_id = aws_eip.app.id
}
