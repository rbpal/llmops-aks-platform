output "grafana_endpoint" { value = azurerm_dashboard_grafana.grafana.endpoint }
output "workspace_id" { value = azurerm_monitor_workspace.amw.id }
