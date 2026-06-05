output "firewall_ids" {
  value = { for k, _ in var.regions : k => azurerm_firewall.fw[k].id }
}
output "firewall_policy_id" { value = azurerm_firewall_policy.fw.id }
output "routing_intent_ids" {
  value = { for k, _ in var.regions : k => azurerm_virtual_hub_routing_intent.ri[k].id }
}

# Log Analytics workspace collecting both firewalls' flow logs (the egress audit trail).
output "firewall_law_id" { value = azurerm_log_analytics_workspace.fw.id }
output "firewall_law_name" { value = azurerm_log_analytics_workspace.fw.name }
