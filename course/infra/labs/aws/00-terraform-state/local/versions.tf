terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.0, < 2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.80, < 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6, < 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "awscc" {
  region = var.aws_region
}
