terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "gcs" {
    prefix = "gcp/wordpress"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
