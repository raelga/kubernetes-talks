terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers {
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
  default_tags {
    tags = {
      Lab   = "wordpress-asg"
      LabId = var.lab_id
    }
  }
}

terraform {
  backend "s3" {
    region       = "us-east-1"
    key          = "wordpress-asg-lesson/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
