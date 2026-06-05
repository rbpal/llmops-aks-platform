# Application Gateway v2 with WAF (regional L7 front door for the AKS app).
# Public frontend IP + WAF_v2; backend = the AKS INTERNAL load balancer's static private
# IP. App Gateway is VNet-injected (gateway_ip_configuration on its dedicated subnet), so it
# routes to that 10.x backend directly — no Private Link / PLS needed.
#
# Post-apply wiring: create the internal ingress Service with
#   service.beta.kubernetes.io/azure-load-balancer-internal: "true"
#   service.beta.kubernetes.io/azure-load-balancer-ipv4: "<var.backend_internal_lb_ip>"
# so the LB frontend lands on the exact IP this backend pool points at.

locals {
  beap     = "beap-genai"
  feport   = "feport-http"
  feip     = "feip-public"
  httpset  = "httpset-genai"
  listener = "listener-http"
  probe    = "probe-healthz"
  rule     = "rule-genai"
}

resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static" # required for App Gateway v2
  sku                 = "Standard"
  tags                = var.tags
}

# WAF policy (OWASP managed ruleset) attached to the gateway in Prevention mode.
resource "azurerm_web_application_firewall_policy" "waf" {
  name                = "waf-llmops-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  policy_settings {
    enabled = true
    mode    = "Prevention"
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}

resource "azurerm_application_gateway" "appgw" {
  name                = "agw-llmops-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
  firewall_policy_id  = azurerm_web_application_firewall_policy.waf.id

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  # Scale-units instead of fixed capacity (v2). min 1 keeps the test cheap.
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

  # Backend = the AKS internal LB's static private IP (same VNet, routed directly).
  backend_address_pool {
    name         = local.beap
    ip_addresses = [var.backend_internal_lb_ip]
  }

  probe {
    name                = local.probe
    protocol            = "Http"
    path                = "/healthz"
    host                = var.backend_internal_lb_ip
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
  }

  backend_http_settings {
    name                  = local.httpset
    cookie_based_affinity = "Disabled"
    port                  = 80 # internal LB :80 -> Service :80 -> pod :8000
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

  request_routing_rule {
    name                       = local.rule
    rule_type                  = "Basic"
    priority                   = 100 # required by azurerm v4
    http_listener_name         = local.listener
    backend_address_pool_name  = local.beap
    backend_http_settings_name = local.httpset
  }
}
