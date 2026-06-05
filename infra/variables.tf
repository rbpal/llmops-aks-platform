variable "subscription_id" { type = string }
variable "tenant_id" { type = string }

variable "environment" {
  type    = string
  default = "dev"
}
variable "location" {
  type    = string
  default = "eastus2"
}
variable "owner" { type = string }
variable "name_suffix" { type = string }

# --- AKS node pool (1->3 autoscale demo) ---
variable "node_min_count" {
  type    = number
  default = 1
}
variable "node_max_count" {
  type    = number
  default = 3
}
variable "node_vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

# --- Networking (BYO VNet shared by AKS + App Gateway) ---
variable "vnet_cidr" {
  type    = string
  default = "10.224.0.0/16"
}
variable "aks_subnet_cidr" {
  type    = string
  default = "10.224.0.0/20" # nodes + internal LB frontend (pods use overlay CIDR)
}
variable "appgw_subnet_cidr" {
  type    = string
  default = "10.224.16.0/24" # App Gateway v2 needs its own dedicated subnet
}
variable "internal_lb_ip" {
  type        = string
  default     = "10.224.0.250" # must be inside aks_subnet_cidr
  description = "Static private IP for the AKS internal LB; set on the ingress Service annotation azure-load-balancer-ipv4 and used as the App Gateway backend."
}

# --- Azure AI Search ---
variable "search_sku" {
  type    = string
  default = "free" # one free service per subscription; "basic" if already used
}

# --- Azure OpenAI ---
variable "openai_account_name" { type = string }
variable "openai_model_version" {
  type    = string
  default = "2024-11-20"
}
variable "openai_model_capacity_tpm" {
  type    = number
  default = 10
}

# --- FinOps budget alert ---
variable "operator_email" { type = string }
variable "budget_amount_usd" {
  type    = number
  default = 50
}
variable "budget_start_date" {
  type        = string
  default     = "2026-06-01T00:00:00Z"
  description = "Must be the first of a month, UTC (RFC3339)."
}
