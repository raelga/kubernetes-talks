provider "aws" {
  region = "eu-west-1"
}

module "vpc" {
  source = "./terraform/modules/aws/vpc/vpc"
  name   = "scratch"
}

module "ec2" {
  source              = "../modules/aws/ec2/spot-instance"
  name                = "scratch"
  vpc                 = module.vpc.vpc_id
  subnet              = module.vpc.subnet_az1_id
  system_user         = "rael"
  github_user         = "raelga"
  instance_type       = "t3a.2xlarge"
  spot_price          = "0.10"
  tcp_allowed_ingress = [22, 80, 81, 8080, 8888, 9999]
}

output "public_ip" {
  value = module.ec2.public_ip
}
