terraform {
  required_version = ">= 1.10, < 2.0"

  # Initially uses the implicit local backend.
  # The S3 backend is enabled later by copying backend.tf.example.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.80, < 6.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.108, < 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6, < 4.0"
    }
  }
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]
}

provider "awscc" {
  region = var.region
}
