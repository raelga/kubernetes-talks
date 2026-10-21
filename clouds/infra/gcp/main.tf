terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

locals {
  cluster_name = "clouds-gke"
  common_labels = {
    project    = "kubernetes-clouds-lab"
    managed_by = "terraform"
  }
}

resource "google_compute_network" "lab" {
  name                    = "${local.cluster_name}-network"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "lab" {
  name                     = "${local.cluster_name}-subnet"
  region                   = var.region
  network                  = google_compute_network.lab.id
  ip_cidr_range            = "10.30.0.0/20"
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.31.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.32.0.0/20"
  }
}

resource "google_container_cluster" "lab" {
  name                     = local.cluster_name
  location                 = var.zone
  network                  = google_compute_network.lab.name
  subnetwork               = google_compute_subnetwork.lab.name
  networking_mode          = "VPC_NATIVE"
  initial_node_count       = 1
  remove_default_node_pool = true
  deletion_protection      = false
  min_master_version       = var.kubernetes_version

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.cluster_api_allowed_cidrs
      content {
        cidr_block   = cidr_blocks.value
        display_name = "lab-operator"
      }
    }
  }

  resource_labels = local.common_labels
}

resource "google_container_node_pool" "lab" {
  name       = "${local.cluster_name}-pool"
  location   = var.zone
  cluster    = google_container_cluster.lab.name
  node_count = 1

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 30
    labels       = local.common_labels
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  management {
    auto_repair  = true
    auto_upgrade = false
  }

  version = var.kubernetes_version
}
