# Type declarations only — ALL values live in infradr.auto.tfvars (single source of truth).
variable "subscription_id" { type = string }
variable "tenant_id" { type = string }

variable "owner" { type = string }
variable "name_suffix" { type = string }
variable "environment" { type = string }

# --- Paired regions ---
variable "primary_location" { type = string }
variable "secondary_location" { type = string }

# --- Per-region address plan (all non-overlapping; required for hub-to-hub) ---
variable "regions" {
  type = map(object({
    location          = string
    priority          = number # AFD origin priority. SAME on all => active-active (load-balanced).
    weight            = number # split among same-priority origins (e.g. 1000/1000 = 50/50).
    hub_cidr          = string
    vnet_cidr         = string
    appgw_subnet_cidr = string
    aks_subnet_cidr   = string
    internal_lb_ip    = string
    pod_cidr          = string
    service_cidr      = string
    dns_service_ip    = string
  }))
}

# --- AKS node pool ---
variable "node_vm_size" { type = string }
variable "node_min_count" { type = number }
variable "node_max_count" { type = number }

# --- FinOps budget alert ---
variable "operator_email" { type = string }
variable "budget_amount_usd" { type = number }
variable "budget_start_date" {
  type        = string
  description = "Must be the first of a month, UTC (RFC3339)."
}
