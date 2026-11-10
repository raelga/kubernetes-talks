output "url" { value = "http://${aws_eip.wordpress.public_ip}/" }
output "public_ip" { value = aws_eip.wordpress.public_ip }
output "instance_id" { value = aws_instance.wordpress.id }
output "database_endpoint" { value = aws_db_instance.wordpress.address }
