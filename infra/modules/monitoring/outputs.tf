output "monitor_workspace_id" { value = azurerm_monitor_workspace.amw.id }
output "grafana_endpoint" { value = azurerm_dashboard_grafana.grafana.endpoint }
output "grafana_name" { value = azurerm_dashboard_grafana.grafana.name }
