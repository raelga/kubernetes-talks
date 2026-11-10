output "vpc_id" { value = module.network.vpc_id }
output "public_subnet_ids" { value = module.network.public_subnet_ids }
output "private_subnet_ids" { value = module.network.private_subnet_ids }
output "app_security_group_id" { value = module.network.app_security_group_id }
output "ssh_security_group_id" { value = module.network.ssh_security_group_id }
