output "vpc_id" { value = aws_vpc.lab.id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
output "app_security_group_id" { value = aws_security_group.app.id }
output "ssh_security_group_id" { value = aws_security_group.ssh.id }
