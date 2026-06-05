# Front Door PROFILE half (created BEFORE the App Gateways).
# Splitting Front Door into profile-first + origins-last breaks the dependency cycle:
#   appgateway WAF must validate the FDID (this profile's resource_guid), while the AFD
#   ORIGINS must know the App Gateway FQDNs. Profile resources need neither, so they go first
#   and expose `fdid`; the origins (modules/frontdoor_origins) come after the App Gateways.
#
# Holds: profile + endpoint + origin group + WAF policy + security policy. No origins/route.
resource "azurerm_cdn_frontdoor_profile" "afd" {
  name                = "afd-llmops-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  sku_name            = "Premium_AzureFrontDoor"
  tags                = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "ep" {
  name                     = "ep-llmops-${var.name_suffix}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id
  tags                     = var.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "og" {
  name                     = "og-genai"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id
  session_affinity_enabled = false

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
    # Wide latency band so BOTH regions stay in the eligible set and split by weight
    # (visible active-active from a single client). Lower to ~50 for latency-optimal routing.
    additional_latency_in_milliseconds = 1000
  }
  health_probe {
    interval_in_seconds = 30
    path                = "/healthz"
    protocol            = "Http"
    request_type        = "GET"
  }
}

resource "azurerm_cdn_frontdoor_firewall_policy" "waf" {
  name                = "afdwaf${var.name_suffix}"
  resource_group_name = var.resource_group_name
  sku_name            = "Premium_AzureFrontDoor"
  enabled             = true
  mode                = "Prevention"

  managed_rule {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    action  = "Block"
  }

  # Demo/teaching custom rule: block mobile clients at the GLOBAL edge by User-Agent.
  # Blocks before the request ever reaches a region (cheapest place to drop traffic).
  # NOTE: User-Agent is trivially spoofable — this is for understanding WAF custom rules,
  # not a real security control. Lowercase transform makes the match case-insensitive.
  custom_rule {
    name     = "BlockMobileUserAgents"
    enabled  = true
    priority = 100
    type     = "MatchRule"
    action   = "Block"

    match_condition {
      match_variable     = "RequestHeader"
      selector           = "User-Agent"
      operator           = "Contains"
      negation_condition = false
      match_values       = ["iphone", "android"]
      transforms         = ["Lowercase"]
    }
  }
}

resource "azurerm_cdn_frontdoor_security_policy" "sec" {
  name                     = "sec-genai"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.waf.id
      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.ep.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}
