# Front Door ORIGINS half (created AFTER the App Gateways, because each origin needs its
# App Gateway FQDN). The profile/endpoint/origin-group/WAF live in modules/frontdoor_profile.
# ACTIVE-ACTIVE: both origins share priority 1, so AFD load-balances across both healthy
# regions (by latency band, split by weight) and fails a region out on its /healthz probe.
# (Set one origin to priority 2 in tfvars => active-passive.) TLS terminates at AFD; HttpOnly
# to the App Gateway origins (App Gw listens on :80).
resource "azurerm_cdn_frontdoor_origin" "o" {
  for_each                      = var.regions
  name                          = "origin-${each.key}"
  cdn_frontdoor_origin_group_id = var.origin_group_id
  enabled                       = true

  host_name          = var.origin_fqdns[each.key]
  origin_host_header = var.origin_fqdns[each.key]
  http_port          = 80
  https_port         = 443
  priority           = each.value.priority # SAME on all origins => active-active
  weight             = each.value.weight   # split among same-priority origins

  certificate_name_check_enabled = false
}

resource "azurerm_cdn_frontdoor_route" "r" {
  name                          = "route-genai"
  cdn_frontdoor_endpoint_id     = var.endpoint_id
  cdn_frontdoor_origin_group_id = var.origin_group_id
  cdn_frontdoor_origin_ids      = [for k in keys(var.regions) : azurerm_cdn_frontdoor_origin.o[k].id]

  forwarding_protocol    = "HttpOnly"
  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  https_redirect_enabled = true
  link_to_default_domain = true
}
