# AKS cluster — 1->3 node autoscale, system-assigned identity, OIDC + workload
# identity (pods read Key Vault without long-lived creds), managed Prometheus metrics.
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-llmops-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = "llmops${var.name_suffix}"

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                 = "system"
    vm_size              = var.node_vm_size
    auto_scaling_enabled = true
    min_count            = var.node_min_count
    max_count            = var.node_max_count
    node_count           = var.node_min_count
  }

  identity {
    type = "SystemAssigned"
  }

  monitor_metrics {} # turns on Azure Monitor managed Prometheus metric collection

  tags = var.tags
}
