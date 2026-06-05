output "aks_name" { value = azurerm_kubernetes_cluster.aks.name }
output "aks_id" { value = azurerm_kubernetes_cluster.aks.id }
output "aks_principal_id" { value = azurerm_kubernetes_cluster.aks.identity[0].principal_id }
output "aks_kubelet_object_id" { value = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id }
