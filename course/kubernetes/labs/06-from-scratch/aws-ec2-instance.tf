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

# Pick a subnet in us-east-1a–f where t3a is available (avoid fixed index / unsupported AZs).
resource "random_integer" "subnet_id" {
  min = 0
  max = 2
}

module "ec2" {
  source = "../../../terraform/modules/aws/ec2/ec2-academy-instance/"

  name                = format("lab-%s", random_id.id.hex)
  vpc                 = data.aws_vpc.default.id
  subnet              = sort(data.aws_subnets.default.ids)[random_integer.subnet_id.result]
  system_user         = "ubuntu"
  github_user         = var.github_user
  instance_type       = "t3a.large"
  tcp_allowed_ingress = [22, 80, 81, 8080, 9000]
  managed_ssh_key_name = "vockey"
}

output "public_ip" {
  value = module.ec2.public_ip
}

output "ssh_host" {
  value = format("%s@%s", module.ec2.system_user, module.ec2.public_ip)
}

output "ssh_cmd" {
  description = "SSH command including AWS Academy vockey and lab-generated key"
  value = nonsensitive(format(
    "ssh -o StrictHostKeyChecking=no -i ~/.ssh/labsuser.pem -i %s %s@%s",
    module.ec2.terraform_private_key_path, module.ec2.system_user, module.ec2.public_ip
  ))
}
