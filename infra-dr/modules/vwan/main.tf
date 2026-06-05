# Virtual WAN + one hub per region. Hubs in one vWAN are auto-meshed (hub-to-hub) for
# east-west DR. The Azure Firewall that secures each hub lives in modules/firewall.
resource "azurerm_virtual_wan" "vwan" {
  name                = "vwan-llmops-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.primary_location
  tags                = var.tags
}

resource "azurerm_virtual_hub" "hub" {
  for_each            = var.regions
  name                = "hub-${each.key}-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = each.value.location
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  address_prefix      = each.value.hub_cidr
  tags                = var.tags
}
