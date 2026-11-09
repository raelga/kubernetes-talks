terraform {
  backend "s3" {
    region       = "us-east-1"
    key          = "ec2-basics/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
