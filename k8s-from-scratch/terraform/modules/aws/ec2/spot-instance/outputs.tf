output "public_ip" {
  value = aws_spot_instance_request.instance.public_ip
}
