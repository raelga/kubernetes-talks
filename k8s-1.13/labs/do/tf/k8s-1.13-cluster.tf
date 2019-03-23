resource "digitalocean_kubernetes_cluster" "k8s-cluster" {
  name    = "BarcelonaCloud-k8s-1-13-tf"
  region  = "lon1"
  version = "1.13.4-do.0"

  node_pool {
    name       = "BarcelonaCloud-k8s-1-13-np-tf"
    size       = "s-2vcpu-2gb"
    node_count = 1
  }
}

provider "kubernetes" {
  host = "${digitalocean_kubernetes_cluster.k8s-cluster.endpoint}"

  client_certificate     = "${base64decode(digitalocean_kubernetes_cluster.k8s-cluster.kube_config.0.client_certificate)}"
  client_key             = "${base64decode(digitalocean_kubernetes_cluster.k8s-cluster.kube_config.0.client_key)}"
  cluster_ca_certificate = "${base64decode(digitalocean_kubernetes_cluster.k8s-cluster.kube_config.0.cluster_ca_certificate)}"
}

output "kube_config" {
  sensitive = true,
  value = "${digitalocean_kubernetes_cluster.k8s-cluster.kube_config.0.raw_config}"
}