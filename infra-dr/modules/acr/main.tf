# Geo-replicated ACR (Premium) — ONE image artifact, replicated to each region so both AKS
# clusters pull from a local replica (faster, survives a region outage). Premium SKU is
# required for geo-replication. The region is injected at runtime via env, not baked per image.
resource "azurerm_container_registry" "acr" {
  name                = "acrllmopsdr${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.primary_location
  sku                 = "Premium"
  admin_enabled       = false
  tags                = var.tags

  dynamic "georeplications" {
    for_each = var.replica_locations
    content {
      location = georeplications.value
    }
  }
}
