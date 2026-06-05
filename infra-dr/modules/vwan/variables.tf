variable "resource_group_name" { type = string }
variable "primary_location" { type = string }
variable "name_suffix" { type = string }
variable "regions" {
  type        = any
  description = "Map of region key -> region object (location, hub_cidr, aks_subnet_cidr, ...)."
}
variable "tags" {
  type    = map(string)
  default = {}
}
