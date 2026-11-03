output "lab_id" {
  value = var.lab_id
}

output "region" {
  value = var.aws_region
}

output "client_cidr" {
  value = var.client_cidr
}

output "message" {
  value = var.message
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "root_volume_id" {
  value = aws_instance.web.root_block_device[0].volume_id
}

output "instance_id" {
  value = aws_instance.web.id
}

output "vpc_id" {
  value = aws_vpc.lab.id
}

output "subnet_id" {
  value = aws_subnet.lab.id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.lab.id
}

output "route_table_id" {
  value = aws_route_table.lab.id
}

output "security_group_id" {
  value = aws_security_group.http.id
}

output "bucket_name" {
  value = awscc_s3_bucket.private.id
}

output "public_ip" {
  value = aws_instance.web.public_ip
}

output "http_url" {
  description = "HTTP without TLS, only for the lab and from client_cidr. Wait for bootstrap."
  value       = "http://${aws_instance.web.public_ip}/"
}
