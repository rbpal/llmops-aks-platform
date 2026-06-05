variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name_suffix" { type = string }

variable "vnet_subnet_id" {
  type        = string
  description = "Subnet the AKS nodes + internal LB live in (BYO VNet shared with App Gateway)."
}

variable "node_vm_size" {
  type    = string
  default = "Standard_D2s_v3" # 2 vCPU — small so high pod CPU requests force node scaling
}

variable "node_min_count" {
  type    = number
  default = 1
}

variable "node_max_count" {
  type    = number
  default = 3
}

variable "tags" {
  type    = map(string)
  default = {}
}
