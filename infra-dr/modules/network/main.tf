# Spoke VNets + subnets per region, and the spoke->hub connections. Created separately from
# the workload so routing intent (vwan module) can apply before AKS comes up.
resource "azurerm_virtual_network" "spoke" {
  for_each            = var.regions
  name                = "vnet-${each.key}-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = each.value.location
  address_space       = [each.value.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "appgw" {
  for_each             = var.regions
  name                 = "snet-appgw"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke[each.key].name
  address_prefixes     = [each.value.appgw_subnet_cidr]
}

resource "azurerm_subnet" "aks" {
  for_each             = var.regions
  name                 = "snet-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke[each.key].name
  address_prefixes     = [each.value.aks_subnet_cidr]
}

resource "azurerm_virtual_hub_connection" "spoke" {
  for_each                  = var.regions
  name                      = "conn-${each.key}-${var.name_suffix}"
  virtual_hub_id            = var.hub_ids[each.key]
  remote_virtual_network_id = azurerm_virtual_network.spoke[each.key].id
}
