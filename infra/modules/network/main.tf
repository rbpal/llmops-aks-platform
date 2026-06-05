# VNet shared by AKS and Application Gateway (step_07: App Gateway -> AKS internal LB).
# App Gateway is VNet-injected, so it reaches the AKS internal LB's private IP directly
# (no Private Link). AKS uses Azure CNI Overlay so pods take a separate pod CIDR and the
# node subnet only holds nodes + the internal load balancer frontend.
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-llmops-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.aks_subnet_cidr]
}

# Application Gateway v2 requires its OWN dedicated subnet (cannot be shared).
resource "azurerm_subnet" "appgw" {
  name                 = "snet-appgw"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.appgw_subnet_cidr]
}
