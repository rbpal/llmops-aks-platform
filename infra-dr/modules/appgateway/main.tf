# Regional inbound edge: App Gateway WAF_v2 (+ X-Served-Region rewrite) -> AKS internal LB,
# plus the App Gateway subnet's carve-out route table (0/0 -> Internet, overriding the vWAN
# routing intent so the control plane stays reachable). The subnet NSG is in modules/nsg.

# Carve-out: keep App Gateway v2's control-plane egress direct (overrides routing intent).
resource "azurerm_route_table" "appgw" {
  name                = "rt-appgw-${var.region_key}-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  route {
    name           = "default-to-internet"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }
}

resource "azurerm_subnet_route_table_association" "appgw" {
  subnet_id      = var.appgw_subnet_id
  route_table_id = azurerm_route_table.appgw.id
}

# ---------- App Gateway WAF_v2 ----------
resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-${var.region_key}-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "llmops-${var.region_key}-${var.name_suffix}"
  tags                = var.tags
}

resource "azurerm_web_application_firewall_policy" "waf" {
  name                = "waf-${var.region_key}-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  policy_settings {
    enabled = true
    mode    = "Prevention"
  }

  # Origin lock-down: the NSG only restricts source to the shared AzureFrontDoor.Backend service
  # tag (every tenant's Front Door). This rule narrows that to OUR profile by requiring the
  # X-Azure-FDID header AFD injects to equal our profile's resource_guid. Missing/mismatched
  # header (e.g. someone pointing their own AFD at our public FQDN) -> blocked. Priority 1 so it
  # evaluates before the managed OWASP set. Lowercase transform since GUIDs are case-insensitive.
  custom_rules {
    name      = "AllowOnlyOurFrontDoor"
    priority  = 1
    rule_type = "MatchRule"
    action    = "Block"

    match_conditions {
      match_variables {
        variable_name = "RequestHeaders"
        selector      = "X-Azure-FDID"
      }
      operator           = "Equal"
      negation_condition = true
      match_values       = [lower(var.expected_fdid)]
      transforms         = ["Lowercase"]
    }
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}

locals {
  beap     = "beap-genai"
  feport   = "feport-http"
  feip     = "feip-public"
  httpset  = "httpset-genai"
  listener = "listener-http"
  probe    = "probe-healthz"
  rule     = "rule-genai"
  rewrite  = "rwset-region"
}

resource "azurerm_application_gateway" "appgw" {
  name                = "agw-${var.region_key}-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
  firewall_policy_id  = azurerm_web_application_firewall_policy.waf.id

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }
  autoscale_configuration {
    min_capacity = 1
    max_capacity = 2
  }

  gateway_ip_configuration {
    name      = "gwip"
    subnet_id = var.appgw_subnet_id
  }

  frontend_port {
    name = local.feport
    port = 80
  }
  frontend_ip_configuration {
    name                 = local.feip
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  backend_address_pool {
    name         = local.beap
    ip_addresses = [var.internal_lb_ip]
  }
  probe {
    name                = local.probe
    protocol            = "Http"
    path                = "/healthz"
    host                = var.internal_lb_ip
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
  }
  backend_http_settings {
    name                  = local.httpset
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
    probe_name            = local.probe
  }

  http_listener {
    name                           = local.listener
    frontend_ip_configuration_name = local.feip
    frontend_port_name             = local.feport
    protocol                       = "Http"
  }

  rewrite_rule_set {
    name = local.rewrite
    rewrite_rule {
      name          = "add-region-header"
      rule_sequence = 100
      response_header_configuration {
        header_name  = "X-Served-Region"
        header_value = var.region_key
      }
    }
  }

  request_routing_rule {
    name                       = local.rule
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = local.listener
    backend_address_pool_name  = local.beap
    backend_http_settings_name = local.httpset
    rewrite_rule_set_name      = local.rewrite
  }

  depends_on = [azurerm_subnet_route_table_association.appgw]
}
