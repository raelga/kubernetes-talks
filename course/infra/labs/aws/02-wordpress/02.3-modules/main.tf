module "network" {
  source    = "../../../../modules/aws/network"
  name      = var.name
  http_cidr = var.http_cidr
}
module "database" {
  source                = "../../../../modules/aws/mysql-rds"
  name                  = var.name
  vpc_id                = module.network.vpc_id
  private_subnet_ids    = module.network.private_subnet_ids
  app_security_group_id = module.network.app_security_group_id
}
module "wordpress" {
  source                = "../../../../modules/aws/wordpress-ec2"
  name                  = var.name
  subnet_id             = module.network.public_subnet_ids[0]
  app_security_group_id = module.network.app_security_group_id
  ssh_security_group_id = module.network.ssh_security_group_id
  ssh_key_name          = var.ssh_key_name
  secret_arn            = module.database.secret_arn
  master_secret_arn     = module.database.master_secret_arn
  instance_profile_name = var.instance_profile_name
  depends_on            = [module.network, module.database]
}
