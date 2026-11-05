terraform {
  backend "s3" {
    key          = "ec2-basics/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
