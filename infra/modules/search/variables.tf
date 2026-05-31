variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name_suffix" { type = string }

variable "sku" {
  type    = string
  default = "free" # one free service per subscription; switch to "basic" if already used
}

variable "tags" {
  type    = map(string)
  default = {}
}
