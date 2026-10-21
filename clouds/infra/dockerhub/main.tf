terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    docker = {
      source  = "docker/docker"
      version = "~> 0.7.0"
    }
  }
}

provider "docker" {}

variable "namespace" {
  description = "Personal Docker Hub namespace used to publish the shared lab image."
  type        = string
  default     = "raelga"
}

resource "docker_hub_repository" "guestbook" {
  namespace   = var.namespace
  name        = "clouds-guestbook"
  description = "Global Guestbook: cluster-local Redis and shared Cloudflare D1."
  private     = false
}

output "image_repository" {
  description = "Public image repository shared by both examples and all cloud providers."
  value       = "docker.io/${docker_hub_repository.guestbook.namespace}/${docker_hub_repository.guestbook.name}"
}
