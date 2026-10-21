output "cluster_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.lab.name
}

output "cluster_region" {
  description = "Azure region hosting the cluster."
  value       = azurerm_kubernetes_cluster.lab.location
}

output "configure_kubectl" {
  description = "Command to add this cluster to the local kubeconfig."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.lab.name} --name ${azurerm_kubernetes_cluster.lab.name} --subscription ${var.subscription_id} --context aks"
}
