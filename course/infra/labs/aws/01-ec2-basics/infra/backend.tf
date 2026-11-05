terraform {
  backend "s3" {
    region       = "eu-west-1"
    key          = "ec2-basics/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
