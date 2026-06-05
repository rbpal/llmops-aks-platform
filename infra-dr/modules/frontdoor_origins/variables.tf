variable "regions" {
  type        = any
  description = "Map of region key -> region object (uses .priority/.weight for A/A vs A/P)."
}
variable "origin_fqdns" {
  type        = map(string)
  description = "region key -> App Gateway FQDN (the AFD origin host)."
}
variable "origin_group_id" {
  type        = string
  description = "AFD origin group id from modules/frontdoor_profile."
}
variable "endpoint_id" {
  type        = string
  description = "AFD endpoint id from modules/frontdoor_profile."
}
variable "tags" {
  type    = map(string)
  default = {}
}
