variable "resource_group_name" { type = string }
variable "primary_location" { type = string }
variable "name_suffix" { type = string }
variable "replica_locations" {
  type        = list(string)
  description = "Regions to geo-replicate the image to (besides primary_location)."
  default     = []
}
variable "tags" {
  type    = map(string)
  default = {}
}
