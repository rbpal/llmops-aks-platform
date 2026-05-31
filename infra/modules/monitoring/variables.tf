variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name_suffix" { type = string }

# AKS cluster id to associate the data collection rule with.
variable "aks_cluster_id" { type = string }

variable "grafana_major_version" {
  type    = string
  default = "11"
}

variable "tags" {
  type    = map(string)
  default = {}
}
