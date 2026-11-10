module "network" {
  source     = "../../../../../modules/aws/network"
  name       = var.name
  cidr_block = var.cidr_block
  http_cidr  = var.http_cidr
}
