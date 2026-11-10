packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0, < 2.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" { type = string }
variable "subnet_id" { type = string }
variable "ssh_cidr" { type = string }
variable "wordpress_version" { type = string }
variable "wordpress_sha256" { type = string }

source "amazon-ebs" "wordpress" {
  region                      = var.region
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  ssh_interface               = "public_ip"
  ssh_username                = "ec2-user"
  temporary_security_group_source_cidrs = [var.ssh_cidr]
  instance_type               = "t4g.small"
  ami_name                    = "wordpress-${var.wordpress_version}-{{timestamp}}"
  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023.*-kernel-6.1-arm64"
      architecture        = "arm64"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    owners      = ["amazon"]
    most_recent = true
  }
  tags = { WordPress = var.wordpress_version, Purpose = "disposable-training" }
}

build {
  sources = ["source.amazon-ebs.wordpress"]
  provisioner "shell" {
    environment_vars = [
      "WORDPRESS_VERSION=${var.wordpress_version}",
      "WORDPRESS_SHA256=${var.wordpress_sha256}"
    ]
    script = "build-image.sh"
  }
}
