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

# Azure OpenAI module
variable "openai_account_name" { type = string }

variable "openai_model_version" {
  type    = string
  default = "2024-11-20"
}

variable "openai_model_capacity_tpm" {
  type    = number
  default = 10
}

# FinOps alerting
variable "operator_email" { type = string }
