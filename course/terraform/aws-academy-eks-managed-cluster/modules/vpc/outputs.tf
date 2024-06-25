output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_a" {
  value = aws_subnet.public_az_a.id
}

output "public_subnet_b" {
  value = aws_subnet.public_az_b.id
}

output "public_subnet_c" {
  value = aws_subnet.public_az_c.id
}

output "private_subnet_a" {
  value = aws_subnet.private_az_a.id
}

output "private_subnet_b" {
  value = aws_subnet.private_az_b.id
}

output "private_subnet_c" {
  value = aws_subnet.private_az_c.id
}
