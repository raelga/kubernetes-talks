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

variable "ingress_cidr" {
  description = "IPv4 CIDR allowed to access the instance."
  type        = string
  default     = "0.0.0.0/0"
}

variable "ecr" {
  description = "Create an ECR repository and attach the Academy instance profile."
  type        = bool
  default     = false
}

resource "aws_ecr_repository" "lab" {
  count        = var.ecr ? 1 : 0
  name         = "k8s-lab-${random_id.id.hex}"
  force_delete = false
}

resource "random_integer" "subnet_id" {
  min = 0
  max = 2
}

module "ec2" {
  source                = "../modules/aws/ec2/ec2-academy-k8s-instance/"
  name                  = format("lab-%s", random_id.id.hex)
  vpc                   = data.aws_vpc.default.id
  subnet                = sort(data.aws_subnets.default.ids)[random_integer.subnet_id.result]
  system_user           = "ec2-user"
  instance_type         = "t3a.large"
  tcp_allowed_ingress   = [22, 80, 81, 8080, 9000]
  ingress_cidr          = var.ingress_cidr
  instance_profile_name = var.ecr ? "LabInstanceProfile" : null
  managed_ssh_key_name  = "vockey"
}

output "ecr_repository_url" {
  value = var.ecr ? aws_ecr_repository.lab[0].repository_url : null
}

output "username" {
  value = module.ec2.system_user
}

output "host" {
  value = format(
    "%s", module.ec2.public_ip
  )
}

output "ssh_cmd" {
  value = format(
    "ssh -o StrictHostKeyChecking=no -i %s %s@%s",
    module.ec2.terraform_private_key_path, module.ec2.system_user, module.ec2.public_ip
  )
  sensitive = true
}

output "ssh_host" {
  value = format(
    "%s@%s", module.ec2.system_user, module.ec2.public_ip
  )
}
