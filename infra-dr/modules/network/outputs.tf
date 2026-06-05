output "vnet_ids" {
  value = { for k, _ in var.regions : k => azurerm_virtual_network.spoke[k].id }
}
output "appgw_subnet_ids" {
  value = { for k, _ in var.regions : k => azurerm_subnet.appgw[k].id }
}
output "aks_subnet_ids" {
  value = { for k, _ in var.regions : k => azurerm_subnet.aks[k].id }
}
