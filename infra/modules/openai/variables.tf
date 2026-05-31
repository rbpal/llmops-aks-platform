variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "account_name" { type = string }

variable "model_capacity_tpm" {
  type    = number
  default = 10 # thousands of tokens/min; keep small for the demo budget
}

# Chat model
variable "chat_deployment_name" {
  type    = string
  default = "gpt-4o-mini"
}
variable "chat_model_name" {
  type    = string
  default = "gpt-4o-mini"
}
variable "chat_model_version" {
  type    = string
  default = "2024-07-18"
}

# Embedding model
variable "embedding_deployment_name" {
  type    = string
  default = "text-embedding-3-small"
}
variable "embedding_model_name" {
  type    = string
  default = "text-embedding-3-small"
}
variable "embedding_model_version" {
  type    = string
  default = "1"
}

variable "tags" {
  type    = map(string)
  default = {}
}
