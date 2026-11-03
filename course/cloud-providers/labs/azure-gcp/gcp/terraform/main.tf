terraform {
  required_version = ">= 1.6, < 2.0"
  required_providers {
    google = { source = "hashicorp/google", version = ">= 6.0, < 8.0" }
    random = { source = "hashicorp/random", version = ">= 3.6, < 4.0" }
  }
  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

locals {
  prefix = "upc-2026-cloud-03-${var.lab_id}"
  labels = { course = "upc-2026", lab = "cloud-03", lab_id = var.lab_id }
}

resource "google_compute_network" "lab" {
  name                    = local.prefix
  auto_create_subnetworks = false
}
resource "google_compute_subnetwork" "lab" {
  name          = "${local.prefix}-subnet"
  ip_cidr_range = "10.43.1.0/24"
  region        = var.region
  network       = google_compute_network.lab.id
}
resource "google_compute_firewall" "http" {
  name          = "${local.prefix}-http"
  network       = google_compute_network.lab.name
  direction     = "INGRESS"
  source_ranges = [var.http_client_cidr]
  target_tags   = [local.prefix]
  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
}
resource "google_compute_instance" "lab" {
  name         = "${local.prefix}-vm"
  machine_type = var.machine_type
  zone         = var.zone
  labels       = local.labels
  tags         = [local.prefix]
  lifecycle {
    precondition {
      condition     = startswith(var.zone, "${var.region}-")
      error_message = "La zona debe pertenecer a la región indicada."
    }
  }
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-standard"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.lab.id
    access_config {}
  }
  metadata = {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
  }
  metadata_startup_script = templatefile("${path.module}/startup.sh.tftpl", {
    lab_id     = var.lab_id
    app_source = file("${path.module}/../../app.py")
  })
  # Sin service_account: la VM no recibe identidad ni claves cloud.
  depends_on = [google_compute_firewall.http]
}

resource "random_id" "storage" {
  count       = var.bucket_name == null ? 1 : 0
  byte_length = 6
}

resource "google_storage_bucket" "lab" {
  name                        = var.bucket_name != null ? var.bucket_name : "${var.project_id}-c03-${var.lab_id}-${random_id.storage[0].hex}"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  labels                      = local.labels
}
