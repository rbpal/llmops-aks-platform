# AKS (CNI overlay) with egress via userDefinedRouting — node egress leaves through the
# vWAN-hub firewall via the routing intent on the spoke. The caller must order this AFTER
# the firewall module (routing intent) so the 0/0 route exists before nodes bootstrap.
#
# outbound_type=userDefinedRouting REQUIRES a route table explicitly associated with the node
# subnet at create time. vWAN routing-intent propagation alone is NOT enough — AKS validation
# fails with "ExistingRouteTableNotAssociatedWithSubnet". So we associate an explicit route table
# whose 0/0 points at the hub firewall's private IP (belt-and-suspenders with routing intent).
resource "azurerm_route_table" "aks" {
  name                = "rt-aks-${var.region_key}-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.firewall_private_ip
  }
}

resource "azurerm_subnet_route_table_association" "aks" {
  subnet_id      = var.aks_subnet_id
  route_table_id = azurerm_route_table.aks.id
}

resource "azurerm_kubernetes_cluster" "aks" {
  # The route-table association must exist before AKS validates its UDR egress.
  depends_on = [azurerm_subnet_route_table_association.aks]

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
