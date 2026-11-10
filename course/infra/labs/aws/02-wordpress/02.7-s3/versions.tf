terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.80, < 6.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6, < 4.0"
    }
  }
}

provider "awscc" {
  region = var.aws_region
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Lab   = "wordpress-asg"
      LabId = var.lab_id
    }
  }
}
