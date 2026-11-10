data "google_client_config" "current" {}

locals {
  db_name = "wordpress"
  db_user = "wordpress"
  salt_names = toset([
    "AUTH_KEY", "SECURE_AUTH_KEY", "LOGGED_IN_KEY", "NONCE_KEY",
    "AUTH_SALT", "SECURE_AUTH_SALT", "LOGGED_IN_SALT", "NONCE_SALT",
  ])
}

resource "google_compute_network" "wordpress" {
  name                    = "wordpress-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "wordpress" {
  name          = "wordpress-subnet"
  region        = var.region
  network       = google_compute_network.wordpress.id
  ip_cidr_range = "10.43.0.0/24"
}

resource "google_compute_global_address" "private_services" {
  name          = "wordpress-private-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.wordpress.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.wordpress.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
}

resource "google_compute_firewall" "ingress" {
  name          = "wordpress-ingress"
  network       = google_compute_network.wordpress.id
  direction     = "INGRESS"
  source_ranges = [var.allowed_source_cidr]
  target_tags   = ["wordpress-lab"]

  allow {
    protocol = "tcp"
    ports    = ["22", "80"]
  }
}

resource "random_password" "db_admin" {
  length  = 32
  special = false
}

resource "random_password" "db_app" {
  length  = 32
  special = false
}

resource "random_password" "salts" {
  for_each = local.salt_names
  length   = 64
  special  = false
}

resource "google_sql_database_instance" "wordpress" {
  name                = "wordpress-mysql"
  region              = var.region
  database_version    = "MYSQL_8_0"
  root_password       = random_password.db_admin.result
  deletion_protection = false

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    disk_size         = 10
    disk_type         = "PD_SSD"

    backup_configuration {
      enabled = false
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.wordpress.id
    }
  }

  depends_on = [google_service_networking_connection.private_services]
}

resource "google_sql_database" "wordpress" {
  name     = local.db_name
  instance = google_sql_database_instance.wordpress.name
}

resource "google_service_account" "wordpress" {
  account_id   = "wordpress-lab-vm"
  display_name = "WordPress lab VM"
}

resource "google_secret_manager_secret" "credentials" {
  for_each  = toset(["db-admin", "db-app", "wp-salts"])
  secret_id = "wordpress-${each.key}"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_admin" {
  secret      = google_secret_manager_secret.credentials["db-admin"].id
  secret_data = random_password.db_admin.result
}

resource "google_secret_manager_secret_version" "db_app" {
  secret      = google_secret_manager_secret.credentials["db-app"].id
  secret_data = random_password.db_app.result
}

resource "google_secret_manager_secret_version" "wp_salts" {
  secret      = google_secret_manager_secret.credentials["wp-salts"].id
  secret_data = jsonencode({ for name, salt in random_password.salts : name => salt.result })
}

resource "google_secret_manager_secret_iam_member" "vm_access" {
  for_each  = google_secret_manager_secret.credentials
  secret_id = each.value.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.wordpress.email}"
}

resource "google_compute_instance" "wordpress" {
  name         = "wordpress-vm"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["wordpress-lab"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.wordpress.id
    access_config {}
  }

  service_account {
    email  = google_service_account.wordpress.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = templatefile("${path.module}/startup.sh.tftpl", {
    bootstrap_script = base64encode(templatefile("${path.module}/bootstrap.py.tftpl", {
      project_id         = data.google_client_config.current.project
      db_host            = google_sql_database_instance.wordpress.private_ip_address
      db_name            = local.db_name
      db_user            = local.db_user
      db_admin_user      = "root"
      db_admin_secret_id = google_secret_manager_secret.credentials["db-admin"].secret_id
      db_app_secret_id   = google_secret_manager_secret.credentials["db-app"].secret_id
      wp_salts_secret_id = google_secret_manager_secret.credentials["wp-salts"].secret_id
      db_server_ca       = google_sql_database_instance.wordpress.server_ca_cert[0].cert
    }))
  })

  depends_on = [
    google_sql_database.wordpress,
    google_secret_manager_secret_version.db_admin,
    google_secret_manager_secret_version.db_app,
    google_secret_manager_secret_version.wp_salts,
    google_secret_manager_secret_iam_member.vm_access,
  ]
}
