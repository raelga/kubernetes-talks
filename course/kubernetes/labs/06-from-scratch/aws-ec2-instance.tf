resource "random_id" "id" {
  byte_length = 8
}

provider "aws" {
  region = "us-east-1"
}

data "aws_region" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "default" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

variable "github_user" {
  description = "GitHub user ID for system account creation and SSH keys"
  type        = string
  default     = "raelga"
}

module "ec2" {
  source               = "../00-Instance-Academy/terraform/modules/aws/ec2-academy/instance"
  name                 = format("lab-%s", random_id.id.hex)
  ami                  = "ami-0cf10cdf9fcd62d37"
  vpc                  = data.aws_vpc.default.id
  subnet               = data.aws_subnets.default.ids[1]
  github_user          = var.github_user
  instance_type        = "r7a.large"
  tcp_allowed_ingress  = [22, 80, 81, 8080, 9000]
  managed_ssh_key_name = "vockey"
}

output "public_ip" {
  value = module.ec2.public_ip
}

output "ssh_host" {
  value = format(
    "%s@%s", module.ec2.system_user, module.ec2.public_ip
  )
}
