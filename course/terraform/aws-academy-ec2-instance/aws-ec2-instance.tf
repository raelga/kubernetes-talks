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

variable "ecr" {
  description = "Create a private ECR repository for the container labs."
  type        = bool
  default     = false
}

resource "aws_ecr_repository" "lab" {
  count        = var.ecr ? 1 : 0
  name         = "container-lab-${random_id.id.hex}"
  force_delete = true
}

output "ecr_repository_url" {
  value = var.ecr ? aws_ecr_repository.lab[0].repository_url : null
}

output "ecr_login_cmd" {
  description = "Run on the instance to authenticate Docker to ECR."
  value       = var.ecr ? "aws ecr get-login-password --region ${data.aws_region.current.region} | docker login --username AWS --password-stdin ${split("/", aws_ecr_repository.lab[0].repository_url)[0]}" : null
}

output "ecr_export_cmds" {
  description = "Run on the instance to set the ECR lab variables."
  value       = var.ecr ? "export REPOSITORY=\"${aws_ecr_repository.lab[0].repository_url}\"\nexport REGISTRY=\"$${REPOSITORY%%/*}\"" : null
}

resource "random_integer" "subnet_id" {
  min = 0
  max = 2
}

module "ec2" {
  source               = "../modules/aws/ec2/ec2-academy-instance/"
  name                 = format("lab-%s", random_id.id.hex)
  vpc                  = data.aws_vpc.default.id
  subnet               = sort(data.aws_subnets.default.ids)[random_integer.subnet_id.result]
  system_user          = "ubuntu"
  instance_type        = "t3a.medium"
  tcp_allowed_ingress  = [22, 80, 81, 8080, 8888, 9999]
  managed_ssh_key_name = "vockey"
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
  value = nonsensitive(format(
    "ssh -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -i %s %s@%s",
    module.ec2.terraform_private_key_path, module.ec2.system_user, module.ec2.public_ip
  ))
}

output "ssh_host" {
  value = format(
    "%s@%s", module.ec2.system_user, module.ec2.public_ip
  )
}
