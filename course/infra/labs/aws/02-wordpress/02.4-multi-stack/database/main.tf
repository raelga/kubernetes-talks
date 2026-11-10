data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "wordpress/network/terraform.tfstate"
    region = var.aws_region
  }
}
module "database" {
  source                  = "../../../../../modules/aws/mysql-rds"
  name                    = var.name
  vpc_id                  = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids      = data.terraform_remote_state.network.outputs.private_subnet_ids
  app_security_group_id   = data.terraform_remote_state.network.outputs.app_security_group_id
  database_instance_class = var.database_instance_class
  mysql_engine_version    = var.mysql_engine_version
}
