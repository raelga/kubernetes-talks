terraform {
  backend "s3" {
    region       = "eu-west-1"
    key          = "wordpress/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
