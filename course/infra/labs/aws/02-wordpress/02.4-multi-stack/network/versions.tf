terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  backend "s3" {
    region       = "us-east-1"
    key          = "wordpress/network/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
provider "aws" { region = var.aws_region }
