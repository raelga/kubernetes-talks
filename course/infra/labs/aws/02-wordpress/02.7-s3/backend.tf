terraform {
  backend "s3" {
    region       = "us-east-1"
    key          = "wordpress-s3/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
