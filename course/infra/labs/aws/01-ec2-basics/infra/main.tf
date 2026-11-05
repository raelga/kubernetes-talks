data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name = "infra-lab-ec2-${var.lab_id}-${random_id.suffix.hex}"
}


resource "aws_security_group" "app" {
  name        = "${local.name}-app"
  description = "Public web access and configurable SSH access"
  vpc_id      = data.aws_vpc.default.id
  tags        = { Name = local.name, Stack = local.name }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.app.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.app.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.app.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_cidr
}

resource "aws_vpc_security_group_egress_rule" "app" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound package downloads and Git checkout"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "app" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = sort(data.aws_subnets.default.ids)[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = var.key_name
  user_data_replace_on_change = true

  user_data = <<-USER_DATA
    #!/bin/bash
    set -euo pipefail
    mkdir -p /opt/infra-lab
    printf '%s' '${filebase64("${path.module}/install.sh")}' | base64 --decode > /opt/infra-lab/install.sh
    bash /opt/infra-lab/install.sh ${jsonencode(var.repository_ref)}
  USER_DATA

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
    tags                  = { Name = local.name, Stack = local.name }
  }

  tags       = { Name = local.name, Stack = local.name }
  depends_on = [aws_vpc_security_group_egress_rule.app]
}
