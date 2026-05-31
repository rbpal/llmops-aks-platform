# Root wiring (step_07_task01): resource group + all modules + identity role
# assignments + a FinOps budget alert. `make up-aks` builds it; `make down-aks` destroys.
data "azurerm_client_config" "current" {}

locals {
  tags = {
    owner       = var.owner
    environment = var.environment
    project     = "llmops-aks-platform"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-llmops-${var.name_suffix}"
  location = var.location
  tags     = local.tags
}

module "acr" {
  source              = "./modules/acr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  name_suffix         = var.name_suffix
  tags                = local.tags
}

module "aks" {
  source              = "./modules/aks"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  name_suffix         = var.name_suffix
  node_min_count      = var.node_min_count
  node_max_count      = var.node_max_count
  node_vm_size        = var.node_vm_size
  tags                = local.tags
}

module "search" {
  source              = "./modules/search"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  name_suffix         = var.name_suffix
  sku                 = var.search_sku
  tags                = local.tags
}

module "key_vault" {
  source              = "./modules/key_vault"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  name_suffix         = var.name_suffix
  tags                = local.tags
}

module "openai" {
  source              = "./modules/openai"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  account_name        = var.openai_account_name
  model_capacity_tpm  = var.openai_model_capacity_tpm
  tags                = local.tags
}

module "monitoring" {
  source              = "./modules/monitoring"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  name_suffix         = var.name_suffix
  aks_cluster_id      = module.aks.id
  tags                = local.tags
}

# --- Identity wiring (no long-lived credentials) ---
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = module.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = module.aks.kubelet_identity_object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "aks_kv_secrets_user" {
  scope                            = module.key_vault.id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = module.aks.kubelet_identity_object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "operator_kv_officer" {
  scope                = module.key_vault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# --- FinOps: budget alert emailing the operator on spend thresholds ---
resource "azurerm_consumption_budget_resource_group" "budget" {
  name              = "budget-llmops-${var.name_suffix}"
  resource_group_id = azurerm_resource_group.rg.id
  amount            = var.budget_amount_usd
  time_grain        = "Monthly"

  time_period {
    start_date = var.budget_start_date # first of a month, UTC (RFC3339)
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"
    contact_emails = [var.operator_email]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Forecasted"
    contact_emails = [var.operator_email]
  }
}
