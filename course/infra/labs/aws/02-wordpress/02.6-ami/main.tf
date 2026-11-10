data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "wordpress/network/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "wordpress/database/terraform.tfstate"
    region = var.aws_region
  }
}

module "wordpress_stack" {
  source = "../../../../modules/aws/wordpress-autoscaling"

  instance_profile_name = var.instance_profile_name
  lab_id                = var.lab_id
  instance_type         = var.instance_type
  wordpress_version     = var.wordpress_version
  wordpress_sha256      = var.wordpress_sha256
  ami_id                = var.ami_id
  vpc_id                = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids     = data.terraform_remote_state.network.outputs.public_subnet_ids
  app_security_group_id = data.terraform_remote_state.network.outputs.app_security_group_id
  database_endpoint     = data.terraform_remote_state.database.outputs.endpoint
  master_secret_arn     = data.terraform_remote_state.database.outputs.master_secret_arn
  domain_name           = var.domain_name
  hosted_zone_id        = var.hosted_zone_id
}
