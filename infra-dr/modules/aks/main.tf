# AKS (CNI overlay) with egress via userDefinedRouting — node egress leaves through the
# vWAN-hub firewall via the routing intent on the spoke. The caller must order this AFTER
# the firewall module (routing intent) so the 0/0 route exists before nodes bootstrap.
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-${var.region_key}-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = "llmops${var.region_key}${var.name_suffix}"

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                 = "system"
    vm_size              = var.node_vm_size
    auto_scaling_enabled = true
    min_count            = var.node_min_count
    max_count            = var.node_max_count
    node_count           = var.node_min_count
    vnet_subnet_id       = var.aks_subnet_id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    load_balancer_sku   = "standard"
    outbound_type       = "userDefinedRouting"
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    pod_cidr            = var.pod_cidr
  }

  monitor_metrics {}

  tags = var.tags
}
