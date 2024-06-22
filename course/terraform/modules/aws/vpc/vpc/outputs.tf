output "vpc_id" {
  value = aws_vpc.main.id
}
output "subnet_az1_id" {
  value = aws_subnet.az1.id
}
output "subnet_az2_id" {
  value = aws_subnet.az2.id
}
output "subnet_az3_id" {
  value = aws_subnet.az3.id
}
