output "id" { value = azurerm_application_gateway.appgw.id }
output "public_ip" { value = azurerm_public_ip.appgw.ip_address }
output "waf_policy_id" { value = azurerm_web_application_firewall_policy.waf.id }
