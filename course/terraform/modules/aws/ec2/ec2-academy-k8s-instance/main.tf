data "aws_ami" "latest" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

}

resource "aws_security_group" "instance-sg" {
  vpc_id = var.vpc

  dynamic "ingress" {
    for_each = var.tcp_allowed_ingress

    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Kubernetes NodePort ranges
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = format("%s-sg", var.name)
  }
}

data "aws_iam_role" "this" {
  name = var.instance_role
}

resource "aws_iam_instance_profile" "this" {
  name = format("%s-%s", var.instance_role, var.name)
  role = data.aws_iam_role.this.name
}

data "aws_key_pair" "managed" {
  count              = var.managed_ssh_key_name != "" ? 1 : 0
  key_name           = var.managed_ssh_key_name
  include_public_key = true
}

resource "aws_eip" "this" {
  domain   = "vpc"
  instance = aws_instance.this.id
}

resource "aws_instance" "this" {
  ami           = var.ami != "" ? var.ami : data.aws_ami.latest.id
  instance_type = var.instance_type
  #iam_instance_profile   = aws_iam_instance_profile.this.name
  subnet_id              = var.subnet
  vpc_security_group_ids = [aws_security_group.instance-sg.id]

  root_block_device {
    volume_size = 32
    volume_type = "gp3"
    tags = {
      Name = var.name
    }
  }

  key_name = try(data.aws_key_pair.managed[0].key_name, null)

  user_data = templatefile(
    "${path.module}/user_data.sh",
    {
      system_user = var.system_user,
      github_user = var.github_user
    }
  )

  tags = {
    Name = var.name
  }
}
