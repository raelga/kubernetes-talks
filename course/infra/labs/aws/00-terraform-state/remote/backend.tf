terraform {
  backend "s3" {
    key          = "terraform-state/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
