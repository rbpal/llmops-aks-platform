variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name_suffix" { type = string }
variable "region_key" { type = string }

variable "aks_subnet_id" { type = string }
variable "firewall_private_ip" {
  type        = string
  description = "Hub firewall private IP; becomes the 0/0 next hop on the AKS subnet route table (required by outbound_type=userDefinedRouting)."
}
variable "pod_cidr" { type = string }
variable "service_cidr" { type = string }
variable "dns_service_ip" { type = string }

variable "node_vm_size" { type = string }
variable "node_min_count" { type = number }
variable "node_max_count" { type = number }

variable "tags" {
  type    = map(string)
  default = {}
}
