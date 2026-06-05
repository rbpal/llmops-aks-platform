output "endpoint_hostname" { value = azurerm_cdn_frontdoor_endpoint.ep.host_name }
output "url" { value = "https://${azurerm_cdn_frontdoor_endpoint.ep.host_name}" }
output "profile_id" { value = azurerm_cdn_frontdoor_profile.afd.id }
output "endpoint_id" { value = azurerm_cdn_frontdoor_endpoint.ep.id }
output "origin_group_id" { value = azurerm_cdn_frontdoor_origin_group.og.id }

# The value Front Door injects in the X-Azure-FDID header on every request (incl. health
# probes) to the origin. App Gateways block requests whose X-Azure-FDID != this GUID, so the
# coarse AzureFrontDoor.Backend service tag (shared across all tenants) is narrowed to OUR AFD.
output "fdid" { value = azurerm_cdn_frontdoor_profile.afd.resource_guid }
