output "resource_group" { value = azurerm_resource_group.rg.name }

# ACR — push the image here (az acr login --name <acr_name>).
output "acr_login_server" { value = module.acr.login_server }
output "acr_name" { value = module.acr.name }

# AKS — `az aks get-credentials -g <rg> -n <aks_name>`.
output "aks_name" { value = module.aks.name }

# Azure AI Search — point VECTOR_STORE=azure_search at this.
output "search_endpoint" { value = module.search.endpoint }
output "search_primary_key" {
  value     = module.search.primary_key
  sensitive = true
}

# Azure OpenAI.
output "openai_endpoint" { value = module.openai.endpoint }
output "openai_chat_deployment" { value = module.openai.chat_deployment_name }
output "openai_embedding_deployment" { value = module.openai.embedding_deployment_name }
output "openai_primary_key" {
  value     = module.openai.primary_key
  sensitive = true
}

# Key Vault — VAULT_BACKEND=key_vault, KEY_VAULT_URI=<this>.
output "key_vault_uri" { value = module.key_vault.uri }
output "key_vault_name" { value = module.key_vault.name }

# Azure Managed Grafana — open this for the tokens/cost/latency dashboard.
output "grafana_endpoint" { value = module.monitoring.grafana_endpoint }
