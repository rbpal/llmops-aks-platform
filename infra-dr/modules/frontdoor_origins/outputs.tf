output "route_id" { value = azurerm_cdn_frontdoor_route.r.id }
output "origin_ids" {
  value = { for k in keys(var.regions) : k => azurerm_cdn_frontdoor_origin.o[k].id }
}
