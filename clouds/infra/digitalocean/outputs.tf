output "cluster_id" {
  description = "DigitalOcean Kubernetes cluster UUID."
  value       = digitalocean_kubernetes_cluster.lab.id
}

output "cluster_name" {
  description = "DOKS cluster name."
  value       = digitalocean_kubernetes_cluster.lab.name
}

output "cluster_region" {
  description = "DigitalOcean region hosting the cluster."
  value       = digitalocean_kubernetes_cluster.lab.region
}

output "configure_kubectl" {
  description = "Command to add this cluster to the local kubeconfig under a stable context."
  value       = "doctl kubernetes cluster kubeconfig save ${digitalocean_kubernetes_cluster.lab.id} --alias doks"
}
