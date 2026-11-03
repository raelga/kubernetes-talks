terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.80.0, < 6.0.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.108.0, < 2.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6, < 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      course = "upc-2026"
      lab    = "cloud-02"
      lab_id = var.lab_id
    }
  }
}

provider "awscc" {
  region = var.aws_region
}
