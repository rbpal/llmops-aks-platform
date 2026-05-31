# Azure Container Registry — holds the app image AKS pulls.
resource "azurerm_container_registry" "acr" {
  name                = "acrllmops${var.name_suffix}" # globally unique, alphanumeric only
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = false # pods pull via AcrPull role, not admin creds
  tags                = var.tags
}
