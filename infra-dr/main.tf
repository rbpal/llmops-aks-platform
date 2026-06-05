# Root orchestration of the multi-region active/passive DR topology.
# This file only CALLS modules + wires outputs; resource definitions live in the modules.
#
# WHERE THINGS ARE (module map):
#   modules/acr/           geo-replicated Premium ACR (one image, replicated to both regions)
#   modules/vwan/          Virtual WAN · 2 hubs
#   modules/firewall/      2 AZURE FIREWALLS (AZFW_Hub, Std) · shared policy + AKS-egress rules
#                          · routing intent (Internet + Private -> firewall)
#   modules/network/       2 spoke VNets · snet-appgw + snet-aks · hub connections
#   modules/nsg/           reusable subnet NSG (profile=appgw control-plane rules | default
#                          baseline) — attached to EVERY subnet (appgw + aks)
#   modules/appgateway/    per region: App Gateway WAF_v2 (+region header) · appgw carve-out UDR
#                          · WAF custom rule validating X-Azure-FDID (locks origin to OUR AFD)
#   modules/aks/           per region: AKS (CNI overlay, userDefinedRouting egress)
#   modules/frontdoor_profile/ AFD Premium + WAF + endpoint + origin group — created FIRST,
#                          exposes the FDID (resource_guid) the App Gateways validate
#   modules/frontdoor_origins/ 2 priority origins (A/A) + route — created LAST (needs appgw FQDNs)
#   modules/observability/ 1 Managed Prometheus workspace · 1 Grafana · per-region DCE/DCR/DCRA
#
# Order (DAG):  vwan -> {firewall, network}
#               frontdoor_profile (independent, early — yields FDID)
#               -> {appgateway (consumes FDID), aks}
#               -> {frontdoor_origins (consumes appgw FQDNs), observability}
#   The frontdoor split breaks the cycle: appgw needs the FDID, frontdoor needs appgw FQDNs.
data "azurerm_client_config" "current" {}

locals {
  tags = {
    owner       = var.owner
    environment = var.environment
    project     = "llmops-aks-platform"
    topology    = "multi-region-dr"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-llmops-dr-${var.name_suffix}"
  location = var.primary_location
  tags     = local.tags
}

# 0. Geo-replicated image registry (one artifact, replica in each region).
module "acr" {
  source              = "./modules/acr"
  resource_group_name = azurerm_resource_group.rg.name
  primary_location    = var.primary_location
  name_suffix         = var.name_suffix
  replica_locations   = [var.secondary_location]
  tags                = local.tags
}

# 1. Virtual WAN + hubs.
module "vwan" {
  source              = "./modules/vwan"
  resource_group_name = azurerm_resource_group.rg.name
  primary_location    = var.primary_location
  name_suffix         = var.name_suffix
  regions             = var.regions
  tags                = local.tags
}

# 1b. Azure Firewall (per hub) + policy + AKS-egress rules + routing intent.
module "firewall" {
  source              = "./modules/firewall"
  resource_group_name = azurerm_resource_group.rg.name
  primary_location    = var.primary_location
  name_suffix         = var.name_suffix
  regions             = var.regions
  hub_ids             = module.vwan.hub_ids
  tags                = local.tags
}

# 2. Spoke VNets + subnets + hub connections (uses the hub ids from vwan).
module "network" {
  source              = "./modules/network"
  resource_group_name = azurerm_resource_group.rg.name
  name_suffix         = var.name_suffix
  regions             = var.regions
  hub_ids             = module.vwan.hub_ids
  tags                = local.tags
}

# 3a-pre. Every subnet gets an NSG. App Gateway subnet = appgw profile (control-plane rules);
# AKS subnet = default profile (baseline, Azure default rules — compliance hygiene).
module "nsg_appgw" {
  for_each = var.regions
  source   = "./modules/nsg"

  resource_group_name = azurerm_resource_group.rg.name
  location            = each.value.location
  name_suffix         = var.name_suffix
  region_key          = each.key
  subnet_name         = "appgw"
  subnet_id           = module.network.appgw_subnet_ids[each.key]
  profile             = "appgw"
  tags                = local.tags

  depends_on = [module.network]
}

module "nsg_aks" {
  for_each = var.regions
  source   = "./modules/nsg"

  resource_group_name = azurerm_resource_group.rg.name
  location            = each.value.location
  name_suffix         = var.name_suffix
  region_key          = each.key
  subnet_name         = "aks"
  subnet_id           = module.network.aks_subnet_ids[each.key]
  profile             = "default"
  tags                = local.tags

  depends_on = [module.network]
}

# 2c. Front Door PROFILE (no origin dependency) — created early so its FDID (resource_guid) is
#     available to the App Gateway WAF rules below. Origins/route come last (frontdoor_origins).
module "frontdoor_profile" {
  source              = "./modules/frontdoor_profile"
  resource_group_name = azurerm_resource_group.rg.name
  name_suffix         = var.name_suffix
  tags                = local.tags
}

# 3a. Per-region App Gateway (WAF + region header) + appgw subnet carve-out route table.
#     WAF validates X-Azure-FDID == our AFD's FDID, so only OUR Front Door can reach the origin.
module "appgateway" {
  for_each = var.regions
  source   = "./modules/appgateway"

  resource_group_name = azurerm_resource_group.rg.name
  location            = each.value.location
  name_suffix         = var.name_suffix
  region_key          = each.key
  appgw_subnet_id     = module.network.appgw_subnet_ids[each.key]
  internal_lb_ip      = each.value.internal_lb_ip
  expected_fdid       = module.frontdoor_profile.fdid
  tags                = local.tags

  # App Gateway v2 requires the GatewayManager NSG rule on its subnet at provision time.
  depends_on = [module.network, module.nsg_appgw]
}

# 3b. Per-region AKS (UDR egress). depends_on firewall+network so the 0/0 -> firewall route
#     exists before nodes bootstrap.
module "aks" {
  for_each = var.regions
  source   = "./modules/aks"

  resource_group_name = azurerm_resource_group.rg.name
  location            = each.value.location
  name_suffix         = var.name_suffix
  region_key          = each.key
  aks_subnet_id       = module.network.aks_subnet_ids[each.key]
  firewall_private_ip = module.firewall.firewall_private_ips[each.key]
  pod_cidr            = each.value.pod_cidr
  service_cidr        = each.value.service_cidr
  dns_service_ip      = each.value.dns_service_ip
  node_vm_size        = var.node_vm_size
  node_min_count      = var.node_min_count
  node_max_count      = var.node_max_count
  tags                = local.tags

  depends_on = [module.firewall, module.network]
}

# 4. Front Door ORIGINS + route (active-active) over the two App Gateways. Created last because
#    each origin needs its App Gateway FQDN; attaches to the profile/origin-group from step 2c.
module "frontdoor_origins" {
  source          = "./modules/frontdoor_origins"
  regions         = var.regions
  origin_group_id = module.frontdoor_profile.origin_group_id
  endpoint_id     = module.frontdoor_profile.endpoint_id
  origin_fqdns    = { for k in keys(var.regions) : k => module.appgateway[k].appgw_fqdn }
  tags            = local.tags
}

# 5. Observability across both regions (single workspace + Grafana).
module "observability" {
  source              = "./modules/observability"
  resource_group_name = azurerm_resource_group.rg.name
  primary_location    = var.primary_location
  name_suffix         = var.name_suffix
  regions             = var.regions
  aks_ids             = { for k in keys(var.regions) : k => module.aks[k].aks_id }
  tags                = local.tags
}

# BYO VNet: each AKS identity needs Network Contributor on its spoke VNet (internal LB, NICs).
resource "azurerm_role_assignment" "aks_network_contributor" {
  for_each             = var.regions
  scope                = module.network.vnet_ids[each.key]
  role_definition_name = "Network Contributor"
  principal_id         = module.aks[each.key].aks_principal_id
}

# Both clusters pull the one image from the geo-replicated ACR (local replica each).
resource "azurerm_role_assignment" "aks_acr_pull" {
  for_each                         = var.regions
  scope                            = module.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = module.aks[each.key].aks_kubelet_object_id
  skip_service_principal_aad_check = true
}

# FinOps budget alert (heavier meter: 2 firewalls + 2 AKS + AFD Premium).
resource "azurerm_consumption_budget_resource_group" "budget" {
  name              = "budget-llmops-dr-${var.name_suffix}"
  resource_group_id = azurerm_resource_group.rg.id
  amount            = var.budget_amount_usd
  time_grain        = "Monthly"

  time_period {
    start_date = var.budget_start_date
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
