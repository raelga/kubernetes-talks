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

# resource "aws_default_subnet" "default" {
#   availability_zone = format("%sa", data.aws_region.current.id)
# }
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
  source               = "../modules/aws/ec2/ec2-academy-instance/"
  name                 = format("lab-%s", random_id.id.hex)
  vpc                  = data.aws_vpc.default.id
  subnet               = data.aws_subnets.default.ids[0]
  system_user          = var.github_user
  github_user          = var.github_user
  instance_type        = "t3a.large"
  tcp_allowed_ingress  = [22, 80, 81, 8080, 8888, 9999]
  managed_ssh_key_name = "vockey"
}

output "username" {
  value = module.ec2.system_user
}

output "http" {
  value = format(
    "http://%s", module.ec2.public_ip
  )
}

output "ssh_cmd" {
  value = format(
    "ssh -A %s@%s", module.ec2.system_user, module.ec2.public_ip
  )
}
