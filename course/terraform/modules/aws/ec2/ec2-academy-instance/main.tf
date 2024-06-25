data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
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

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
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
  ami                    = var.ami != "" ? var.ami : data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.this.name
  subnet_id              = var.subnet
  vpc_security_group_ids = [aws_security_group.instance-sg.id]

  key_name = try(data.aws_key_pair.managed[0].key_name, null)

  root_block_device {
    volume_size = 32
    volume_type = "gp3"
    tags = {
      Name = var.name
    }
  }

  user_data = <<EOF
#!/bin/bash
# User configuration
usermod -c ${var.system_user} -l ${var.system_user} -d /home/${var.system_user} -m ${var.system_default_user} && groupmod -n ${var.system_user} ${var.system_default_user};
echo "${var.system_user} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-cloud-init-users
curl -sq https://github.com/${var.github_user}.keys | tee -a /home/${var.system_user}/.ssh/authorized_keys
# Package installation
# Terraform Repository
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
sudo apt-get -y install make apt-transport-https ca-certificates curl gnupg2 software-properties-common jq docker.io cgroup-tools tree awscli terraform
usermod -aG docker ${var.system_user}
reboot
EOF

  tags = {
    Name = var.name
  }
}
