variable "name" {
  type    = string
  default = "wp-split"
}
variable "cidr_block" {
  type    = string
  default = "10.53.0.0/16"
}
variable "http_cidr" {
  description = "Client IPv4 CIDR allowed to reach the disposable HTTP site."
  type        = string
  default     = "0.0.0.0/0"
}
module "network" {
  source     = "../../../../../modules/aws/network"
  name       = var.name
  cidr_block = var.cidr_block
  http_cidr  = var.http_cidr
}
output "vpc_id" { value = module.network.vpc_id }
output "public_subnet_ids" { value = module.network.public_subnet_ids }
output "private_subnet_ids" { value = module.network.private_subnet_ids }
output "app_security_group_id" { value = module.network.app_security_group_id }
output "ssh_security_group_id" { value = module.network.ssh_security_group_id }
