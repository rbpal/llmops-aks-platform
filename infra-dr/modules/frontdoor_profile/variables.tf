variable "resource_group_name" { type = string }
variable "name_suffix" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
