# Azure-native observability: Azure Monitor Workspace (Prometheus metrics store) +
# data collection endpoint/rule wired to AKS + Azure Managed Grafana. The app's
# /metrics is scraped by the managed ama-metrics agent (enabled via monitor_metrics
# on the cluster) and routed here by the DCR association below.

resource "azurerm_monitor_workspace" "amw" {
  name                = "amw-llmops-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_monitor_data_collection_endpoint" "dce" {
  name                = "dce-llmops-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "Linux"
  tags                = var.tags
}

resource "azurerm_monitor_data_collection_rule" "dcr" {
  name                        = "dcr-llmops-${var.name_suffix}"
  resource_group_name         = var.resource_group_name
  location                    = var.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.dce.id
  kind                        = "Linux"

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

  tags = var.tags
}

resource "azurerm_monitor_data_collection_rule_association" "dcra" {
  name                    = "dcra-llmops-${var.name_suffix}"
  target_resource_id      = var.aks_cluster_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr.id
}

resource "azurerm_dashboard_grafana" "grafana" {
  name                  = "graf-llmops-${var.name_suffix}" # 2-23 chars, globally unique
  resource_group_name   = var.resource_group_name
  location              = var.location
  grafana_major_version = var.grafana_major_version

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.amw.id
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "grafana_reader" {
  scope                            = azurerm_monitor_workspace.amw.id
  role_definition_name             = "Monitoring Data Reader"
  principal_id                     = azurerm_dashboard_grafana.grafana.identity[0].principal_id
  skip_service_principal_aad_check = true
}
