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
module "wordpress" {
  source                = "../../../../../modules/aws/wordpress-ec2"
  name                  = var.name
  subnet_id             = data.terraform_remote_state.network.outputs.public_subnet_ids[0]
  app_security_group_id = data.terraform_remote_state.network.outputs.app_security_group_id
  ssh_security_group_id = data.terraform_remote_state.network.outputs.ssh_security_group_id
  ssh_key_name          = var.ssh_key_name
  secret_arn            = data.terraform_remote_state.database.outputs.secret_arn
  master_secret_arn     = data.terraform_remote_state.database.outputs.master_secret_arn
  instance_profile_name = var.instance_profile_name
  instance_type         = var.instance_type
  wordpress_version     = var.wordpress_version
  wordpress_sha256      = var.wordpress_sha256
}
