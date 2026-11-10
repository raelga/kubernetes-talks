module "wordpress_stack" {
  source = "../../../modules/aws/wordpress-stack"

  instance_profile_name   = var.instance_profile_name
  lab_id                  = var.lab_id
  instance_type           = var.instance_type
  wordpress_version       = var.wordpress_version
  wordpress_sha256        = var.wordpress_sha256
  database_instance_class = var.database_instance_class
  mysql_engine_version    = var.mysql_engine_version
  domain_name             = var.domain_name
  hosted_zone_id          = var.hosted_zone_id
}
