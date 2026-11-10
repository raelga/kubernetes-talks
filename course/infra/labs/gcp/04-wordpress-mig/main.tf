module "wordpress_mig" {
  source = "../../../modules/gcp/wordpress-mig"

  name_prefix         = var.name_prefix
  region              = var.region
  zone                = var.zone
  allowed_source_cidr = var.allowed_source_cidr
}
