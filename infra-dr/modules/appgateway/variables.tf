variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name_suffix" { type = string }
variable "region_key" {
  type        = string
  description = "Short region key — used in names + the X-Served-Region response header."
}
variable "appgw_subnet_id" { type = string }
variable "internal_lb_ip" {
  type        = string
  description = "Static private IP of the AKS internal LB (the App Gateway backend target)."
}
variable "expected_fdid" {
  type        = string
  description = <<-EOT
    Our Front Door's ID (frontdoor_profile.fdid / profile resource_guid). The WAF blocks any
    request whose X-Azure-FDID header != this value, narrowing the shared AzureFrontDoor.Backend
    NSG service tag down to OUR Front Door profile. AFD sends this header on every request,
    including health probes, so the lock-down doesn't break probing.
  EOT
}
variable "tags" {
  type    = map(string)
  default = {}
}
