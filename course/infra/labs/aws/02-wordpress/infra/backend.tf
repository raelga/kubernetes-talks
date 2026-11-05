terraform {
  backend "s3" {
    key          = "wordpress/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
