variable "resource_group_name" { type = string }
variable "name_suffix" { type = string }
variable "regions" {
  type        = any
  description = "Map of region key -> region object."
}
variable "hub_ids" {
  type        = map(string)
  description = "region key -> virtual hub id (from the vwan module)."
}
variable "tags" {
  type    = map(string)
  default = {}
}
