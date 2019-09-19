
data "terraform_remote_state" "aws_network" {
  backend = "s3"
  config = {
    region         = "eu-west-1"
    key            = "aws-network"
    bucket         = "tf-state-talks"
    dynamodb_table = "tf-state-talks-locks"
  }
}

module "ec2" {
  source              = "../../modules/aws/ec2/spot-instance"
  name                = "sandbox"
  vpc                 = "${data.terraform_remote_state.aws_network.outputs.vpc_id}"
  subnet              = "${data.terraform_remote_state.aws_network.outputs.subnet_az1_id}"
  system_user         = "rael"
  github_user         = "raelga"
  instance_type       = "t3a.2xlarge"
  spot_price          = "0.10"
  tcp_allowed_ingress = [ 22, 80, 443 ]
}
