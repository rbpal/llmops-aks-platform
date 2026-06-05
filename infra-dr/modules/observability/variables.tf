variable "resource_group_name" { type = string }
variable "primary_location" { type = string }
variable "name_suffix" { type = string }
variable "regions" {
  type        = any
  description = "Map of region key -> region object."
}
variable "aks_ids" {
  type        = map(string)
  description = "region key -> AKS cluster id (DCR association target)."
}
variable "tags" {
  type    = map(string)
  default = {}
}
