# Azure Firewall Standard secured into each vWAN hub, a shared policy with the AKS egress
# allow-list, and the routing intent that sends spoke Internet + Private traffic to the FW.
# AKS uses outbound_type=userDefinedRouting, so the egress rules here MUST cover the AKS
# required endpoints or nodes won't bootstrap.
resource "azurerm_firewall_policy" "fw" {
  name                = "afwp-llmops-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.primary_location
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "egress" {
  name               = "aks-egress"
  firewall_policy_id = azurerm_firewall_policy.fw.id
  priority           = 200

  application_rule_collection {
    name     = "aks-app"
    priority = 200
    action   = "Allow"
    rule {
      name                  = "aks-required-fqdns"
      source_addresses      = [for k, v in var.regions : v.aks_subnet_cidr]
      destination_fqdn_tags = ["AzureKubernetesService"]
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
    }
  }

  network_rule_collection {
    name     = "aks-net"
    priority = 210
    action   = "Allow"

    # DEMO ONLY — permissive egress so nothing silently fails at AKS bootstrap. The firewall stays
    # in-path and LOGS every flow (see diagnostic settings below), so you can show what actually
    # egressed and then tighten. To restore deny-by-default, delete THIS rule; the curated rules
    # below it document the real AKS requirements.
    rule {
      name                  = "allow-all-egress-demo"
      source_addresses      = [for k, v in var.regions : v.aks_subnet_cidr]
      destination_addresses = ["*"]
      destination_ports     = ["1-65535"]
      protocols             = ["TCP", "UDP"]
    }
    rule {
      name                  = "aks-azurecloud"
      source_addresses      = [for k, v in var.regions : v.aks_subnet_cidr]
      destination_addresses = ["AzureCloud"]
      destination_ports     = ["443", "1194", "9000"]
      protocols             = ["TCP", "UDP"]
    }
    rule {
      name                  = "dns-ntp"
      source_addresses      = [for k, v in var.regions : v.aks_subnet_cidr]
      destination_addresses = ["*"]
      destination_ports     = ["53", "123"]
      protocols             = ["TCP", "UDP"]
    }
  }
}

resource "azurerm_firewall" "fw" {
  for_each            = var.regions
  name                = "afw-${each.key}-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = each.value.location
  sku_name            = "AZFW_Hub"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.fw.id
  tags                = var.tags

  virtual_hub {
    virtual_hub_id  = var.hub_ids[each.key]
    public_ip_count = 1
  }
}

resource "azurerm_virtual_hub_routing_intent" "ri" {
  for_each       = var.regions
  name           = "ri-${each.key}-${var.name_suffix}"
  virtual_hub_id = var.hub_ids[each.key]

  routing_policy {
    name         = "InternetTraffic"
    destinations = ["Internet"]
    next_hop     = azurerm_firewall.fw[each.key].id
  }
  routing_policy {
    name         = "PrivateTraffic"
    destinations = ["PrivateTraffic"]
    next_hop     = azurerm_firewall.fw[each.key].id
  }
}

# --- Egress observability: log every firewall flow so the permissive demo rule is auditable. ---
# A Log Analytics workspace lives HERE (not in modules/observability, which is a Prometheus
# workspace and runs AFTER the firewall in the DAG — referencing it would create a cycle). One
# shared workspace; both firewalls send AzureFirewallNetworkRule/ApplicationRule logs to it.
# Query later: AZFWNetworkRule | where Action == "Allow" | summarize by Fqdn, DestinationPort
# — that's the observed allow-list you'd promote when tightening back to deny-by-default.
resource "azurerm_log_analytics_workspace" "fw" {
  name                = "law-afw-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.primary_location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "fw" {
  for_each                   = var.regions
  name                       = "diag-afw-${each.key}-${var.name_suffix}"
  target_resource_id         = azurerm_firewall.fw[each.key].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.fw.id

  enabled_log {
    category_group = "allLogs"
  }
  enabled_metric {
    category = "AllMetrics"
  }
}
