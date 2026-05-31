# Root wiring. TODO(step_07_task01): resource group + modules.
resource "azurerm_resource_group" "rg" {
  name     = "rg-llmops-${var.name_suffix}"
  location = var.location
  tags     = { owner = var.owner, environment = var.environment }
}

# TODO(step_07): module "acr"      { source = "./modules/acr" ... }
# TODO(step_07): module "aks"      { source = "./modules/aks" ... }      # 1->3 autoscale + AcrPull + managed Prometheus
# TODO(step_07): module "search"   { source = "./modules/search" ... }   # Azure AI Search (Free SKU)
# TODO(step_07): module "monitoring"{ source = "./modules/monitoring" ...} # Monitor Workspace + DCR + Managed Grafana
# TODO(step_07): module "key_vault"{ source = "./modules/key_vault" ...}  # decision: secret + PII store
# TODO(step_07): module "openai"   { source = "./modules/openai" ...}     # Azure OpenAI account + model deployment
