resource "google_compute_network" "lab" {
  name                    = "compute-basics-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "lab" {
  name          = "compute-basics-subnet"
  region        = var.region
  network       = google_compute_network.lab.id
  ip_cidr_range = "10.42.0.0/24"
}

resource "google_compute_firewall" "lab_ingress" {
  name          = "compute-basics-ingress"
  network       = google_compute_network.lab.id
  direction     = "INGRESS"
  source_ranges = [var.allowed_source_cidr]
  target_tags   = ["compute-basics"]

  allow {
    protocol = "tcp"
    ports    = ["22", "8080"]
  }
}

resource "google_compute_instance" "lab" {
  name         = "compute-basics-vm"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["compute-basics"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.lab.id
    access_config {}
  }

  # OS Login avoids distributing project or instance metadata SSH keys.
  metadata = {
    enable-oslogin = "TRUE"
  }
  metadata_startup_script = file("${path.module}/startup.sh")
}
