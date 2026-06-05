# One Managed Prometheus workspace + one Managed Grafana, with a per-region DCR scraping each
# AKS into the shared workspace -> a single dashboard where failover (traffic by region) shows.
resource "azurerm_monitor_workspace" "amw" {
  name                = "amw-llmops-dr-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.primary_location
  tags                = var.tags
}

resource "azurerm_monitor_data_collection_endpoint" "dce" {
  for_each            = var.regions
  name                = "dce-${each.key}-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = each.value.location
  kind                = "Linux"
  tags                = var.tags
}

resource "azurerm_monitor_data_collection_rule" "dcr" {
  for_each                    = var.regions
  name                        = "dcr-${each.key}-${var.name_suffix}"
  resource_group_name         = var.resource_group_name
  location                    = each.value.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.dce[each.key].id
  tags                        = var.tags

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.amw.id
      name               = "MonitoringAccount1"
    }
  }
  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount1"]
  }
  data_sources {
    prometheus_forwarder {
      streams = ["Microsoft-PrometheusMetrics"]
      name    = "PrometheusDataSource"
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "dcra" {
  for_each                = var.regions
  name                    = "dcra-${each.key}-${var.name_suffix}"
  target_resource_id      = var.aks_ids[each.key]
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr[each.key].id
}

resource "azurerm_dashboard_grafana" "grafana" {
  name                  = "graf-llmops-${var.name_suffix}"
  resource_group_name   = var.resource_group_name
  location              = var.primary_location
  grafana_major_version = "11"
  tags                  = var.tags

  identity {
    type = "SystemAssigned"
  }
  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.amw.id
  }
}

resource "azurerm_role_assignment" "grafana_reader" {
  scope                = azurerm_monitor_workspace.amw.id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azurerm_dashboard_grafana.grafana.identity[0].principal_id
}
