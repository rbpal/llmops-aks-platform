variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name_suffix" { type = string }

variable "appgw_subnet_id" {
  type        = string
  description = "Dedicated subnet for App Gateway v2."
}

variable "backend_internal_lb_ip" {
  type        = string
  description = "Static private IP of the AKS internal load balancer (the backend pool target)."
}

variable "tags" {
  type    = map(string)
  default = {}
}
