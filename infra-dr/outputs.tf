output "resource_group" { value = azurerm_resource_group.rg.name }

# Geo-replicated ACR — push the one image here; both regions pull a local replica.
output "acr_login_server" { value = module.acr.login_server }
output "acr_name" { value = module.acr.name }

# Front Door — Maya's single global entrypoint (curl this for the failover test).
output "afd_endpoint_hostname" { value = module.frontdoor_profile.endpoint_hostname }
output "afd_url" { value = module.frontdoor_profile.url }

# X-Azure-FDID our App Gateways enforce. Also set this as EXPECTED_FDID env on the pods for
# defense-in-depth (the app rejects /chat requests whose X-Azure-FDID != this value).
output "afd_fdid" {
  value     = module.frontdoor_profile.fdid
  sensitive = false
}

# Per-region App Gateway FQDNs (AFD origins) + public IPs + AKS names.
output "appgw_fqdns" {
  value = { for k in keys(var.regions) : k => module.appgateway[k].appgw_fqdn }
}
output "appgw_public_ips" {
  value = { for k in keys(var.regions) : k => module.appgateway[k].appgw_public_ip }
}
output "aks_names" {
  value = { for k in keys(var.regions) : k => module.aks[k].aks_name }
}

# kubectl context setup for the failover test.
output "aks_get_credentials" {
  value = { for k in keys(var.regions) : k => "az aks get-credentials -g ${azurerm_resource_group.rg.name} -n ${module.aks[k].aks_name}" }
}

# Managed Grafana — the single dashboard where failover (traffic by region) is visible.
output "grafana_endpoint" { value = module.observability.grafana_endpoint }

# Firewall egress audit (demo uses a permissive allow rule, but logs every flow here).
# Query: AZFWNetworkRule | where Action == "Allow" | summarize by Fqdn, DestinationPort
output "firewall_law_name" { value = module.firewall.firewall_law_name }
