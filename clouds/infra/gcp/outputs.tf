output "cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.lab.name
}

output "cluster_region" {
  description = "GCP region hosting the cluster."
  value       = var.region
}

output "cluster_zone" {
  description = "GKE zone hosting the cluster."
  value       = var.zone
}

output "configure_kubectl" {
  description = "Commands to fetch credentials and set the local gke context alias; cloud cluster names are unchanged."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.lab.name} --location ${var.zone} --project ${var.project_id} --account=me@rael.io\nkubectl config rename-context gke_${var.project_id}_${var.zone}_${google_container_cluster.lab.name} gke"
}
