terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {}

resource "digitalocean_kubernetes_cluster" "lab" {
  name         = var.cluster_name
  region       = var.region
  version      = var.kubernetes_version
  auto_upgrade = false
  ha           = var.control_plane_ha

  control_plane_firewall {
    enabled           = true
    allowed_addresses = var.control_plane_allowed_cidrs
  }

  node_pool {
    name       = "lab-workers"
    size       = "s-4vcpu-8gb"
    node_count = 1
    tags       = ["kubernetes-clouds-lab", "terraform"]
  }
}
