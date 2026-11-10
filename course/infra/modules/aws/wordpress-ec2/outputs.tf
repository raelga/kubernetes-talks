output "public_ip" { value = aws_eip.app.public_ip }
output "url" { value = "http://${aws_eip.app.public_ip}/" }
