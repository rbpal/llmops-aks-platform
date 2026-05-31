output "id" { value = azurerm_kubernetes_cluster.aks.id }
output "name" { value = azurerm_kubernetes_cluster.aks.name }
output "node_resource_group" { value = azurerm_kubernetes_cluster.aks.node_resource_group }
output "oidc_issuer_url" { value = azurerm_kubernetes_cluster.aks.oidc_issuer_url }

# Kubelet identity — used for the AcrPull role assignment.
output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

# Cluster (control-plane) identity principal id.
output "principal_id" {
  value = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}
