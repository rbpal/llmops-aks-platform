# Azure Key Vault — primary store for app secrets and the PII vault (project decision).
# RBAC authorization; role assignments live in the root module.
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                       = "kv-llmops-${var.name_suffix}" # 3-24 chars, globally unique
  resource_group_name        = var.resource_group_name
  location                   = var.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = false # demo: allow clean teardown
  soft_delete_retention_days = 7
  tags                       = var.tags
}
