# Azure AI Search — managed vector store the stateless pods query over the network.
# Free SKU: 3 indexes / 50 MB, one free service per subscription, no SLA — fine for demo.
resource "azurerm_search_service" "search" {
  name                         = "srch-llmops-${var.name_suffix}" # globally unique
  resource_group_name          = var.resource_group_name
  location                     = var.location
  sku                          = var.sku
  partition_count              = 1
  replica_count                = 1
  local_authentication_enabled = true # app uses AZURE_SEARCH_API_KEY (prod prefers RBAC)
  tags                         = var.tags
}
