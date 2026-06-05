output "appgw_public_ip" { value = azurerm_public_ip.appgw.ip_address }
output "appgw_fqdn" { value = azurerm_public_ip.appgw.fqdn }
output "appgw_id" { value = azurerm_application_gateway.appgw.id }
