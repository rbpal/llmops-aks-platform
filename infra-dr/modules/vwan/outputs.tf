output "vwan_id" { value = azurerm_virtual_wan.vwan.id }
output "hub_ids" {
  value = { for k, _ in var.regions : k => azurerm_virtual_hub.hub[k].id }
}
