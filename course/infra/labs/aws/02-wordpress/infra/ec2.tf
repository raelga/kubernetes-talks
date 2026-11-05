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

resource "random_shuffle" "subnet" {
  input        = sort(aws_subnet.private[*].id)
  result_count = 1
}

resource "aws_instance" "app" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = random_shuffle.subnet.result[0]
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = data.aws_iam_instance_profile.app.name
  user_data_replace_on_change = true
  lifecycle {
    ignore_changes = [ami]
  }
  user_data = <<-USERDATA
    #!/bin/bash
    set -euo pipefail
    install -d -m 0755 /opt/infra-lab
    printf '%s' '${filebase64("${path.module}/install.sh")}' | base64 --decode > /opt/infra-lab/install.sh
    bash /opt/infra-lab/install.sh ${jsonencode(var.repository_ref)} ${jsonencode(var.wordpress_version)}
  USERDATA
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
    tags                  = { Name = local.name }
  }
  tags = { Name = local.name }
  depends_on = [
    aws_route_table_association.private,
    aws_route_table_association.public,
    aws_vpc_security_group_egress_rule.web,
    aws_vpc_security_group_egress_rule.dns
  ]
}
