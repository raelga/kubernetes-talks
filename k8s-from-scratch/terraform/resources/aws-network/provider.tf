provider "aws" {
  region  = "eu-west-1"
  profile = "terraform"
}

terraform {
  backend "s3" {
    region         = "eu-west-1"
    key            = "aws-network"
    bucket         = "tf-state-talks"
    dynamodb_table = "tf-state-talks-locks"
  }
}
