# Reusable subnet NSG. profile=default -> baseline (Azure default rules only, so every subnet
# has an NSG for compliance). profile=appgw -> App Gateway v2 control-plane rules
# (GatewayManager 65200-65535 inbound is mandatory; LB probes; Front Door origin lock-down).
locals {
  appgw_rules = [
    { name = "AllowGatewayManager", priority = 100, protocol = "Tcp", ports = ["65200-65535"], source = "GatewayManager" },
    { name = "AllowAzureLoadBalancer", priority = 110, protocol = "*", ports = ["0-65535"], source = "AzureLoadBalancer" },
    { name = "AllowFrontDoorInbound", priority = 120, protocol = "Tcp", ports = ["80", "443"], source = "AzureFrontDoor.Backend" },
  ]
  rules = var.profile == "appgw" ? local.appgw_rules : []
}

resource "azurerm_network_security_group" "this" {
  name                = "nsg-${var.subnet_name}-${var.region_key}-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  dynamic "security_rule" {
    for_each = local.rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = security_rule.value.protocol
      source_port_range          = "*"
      destination_port_ranges    = security_rule.value.ports
      source_address_prefix      = security_rule.value.source
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = var.subnet_id
  network_security_group_id = azurerm_network_security_group.this.id
}
