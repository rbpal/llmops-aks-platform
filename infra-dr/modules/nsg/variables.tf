variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name_suffix" { type = string }
variable "region_key" { type = string }
variable "subnet_name" {
  type        = string
  description = "Short subnet label for naming (e.g. appgw, aks)."
}
variable "subnet_id" {
  type        = string
  description = "Subnet to associate this NSG with."
}
variable "profile" {
  type        = string
  default     = "default"
  description = "default = baseline NSG (Azure default rules only); appgw = App Gateway control-plane rules."
  validation {
    condition     = contains(["default", "appgw"], var.profile)
    error_message = "profile must be 'default' or 'appgw'."
  }
}
variable "tags" {
  type    = map(string)
  default = {}
}
