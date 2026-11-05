terraform {
  backend "s3" {
    region       = "eu-west-1"
    key          = "terraform-state/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
