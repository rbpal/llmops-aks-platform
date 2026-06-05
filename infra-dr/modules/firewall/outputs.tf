output "firewall_ids" {
  value = { for k, _ in var.regions : k => azurerm_firewall.fw[k].id }
}
output "firewall_policy_id" { value = azurerm_firewall_policy.fw.id }
output "routing_intent_ids" {
  value = { for k, _ in var.regions : k => azurerm_virtual_hub_routing_intent.ri[k].id }
}

# Each hub firewall's private IP — the next hop for the AKS subnet's 0/0 route table.
# AKS outbound_type=userDefinedRouting requires an explicit route table associated with the
# node subnet; vWAN routing-intent propagation alone does not satisfy that create-time check.
output "firewall_private_ips" {
  value = { for k, _ in var.regions : k => azurerm_firewall.fw[k].virtual_hub[0].private_ip_address }
}

# Log Analytics workspace collecting both firewalls' flow logs (the egress audit trail).
output "firewall_law_id" { value = azurerm_log_analytics_workspace.fw.id }
output "firewall_law_name" { value = azurerm_log_analytics_workspace.fw.name }
