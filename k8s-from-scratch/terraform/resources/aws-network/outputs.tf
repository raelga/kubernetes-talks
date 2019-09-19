output "vpc_id" {
  value = "${module.vpc.vpc_id}"
}

output "subnet_az1_id" {
  value = "${module.vpc.subnet_az1_id}"
}
output "subnet_az2_id" {
  value = "${module.vpc.subnet_az2_id}"
}
output "subnet_az3_id" {
  value = "${module.vpc.subnet_az3_id}"
}