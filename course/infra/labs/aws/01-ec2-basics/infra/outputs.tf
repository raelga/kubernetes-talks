output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  value = data.aws_region.current.name
}

output "lab_id" {
  value = var.lab_id
}

output "application_url" {
  value = "http://${aws_instance.app.public_ip}"
}

output "instance_id" {
  value = aws_instance.app.id
}

output "public_ip" {
  value = aws_instance.app.public_ip
}

output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "app_security_group_id" {
  value = aws_security_group.app.id
}
