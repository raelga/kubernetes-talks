data "aws_caller_identity" "current" {}

data "aws_ami" "ubuntu" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  name = "upc-2026-cloud-02-${var.lab_id}"
}

resource "aws_vpc" "lab" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = local.name }
}

resource "aws_subnet" "lab" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.42.1.0/24"
  map_public_ip_on_launch = false
  tags                    = { Name = local.name }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = local.name }
}

resource "aws_route_table" "lab" {
  vpc_id = aws_vpc.lab.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }
  tags = { Name = local.name }
}

resource "aws_route_table_association" "lab" {
  subnet_id      = aws_subnet.lab.id
  route_table_id = aws_route_table.lab.id
}

resource "aws_security_group" "http" {
  name        = local.name
  description = "HTTP solo desde el cliente; sin SSH"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "Cliente del laboratorio"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = [var.client_cidr]
  }
  egress {
    description = "Salida DNS para repositorios Ubuntu"
    protocol    = "udp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "DNS TCP"
    protocol    = "tcp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Repositorios Ubuntu HTTP"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Repositorios Ubuntu HTTPS"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = local.name }
}

resource "aws_instance" "web" {
  ami                         = var.ami_id != null ? var.ami_id : data.aws_ami.ubuntu[0].id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.lab.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.http.id]
  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    app_base64    = filebase64("${path.module}/app.py")
    config_base64 = base64encode(jsonencode({ message = var.message, lab_id = var.lab_id, provider = "aws" }))
  })
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    tags = {
      Name   = local.name
      course = "upc-2026"
      lab    = "cloud-02"
      lab_id = var.lab_id
    }
  }
  tags       = { Name = local.name }
  depends_on = [aws_route_table_association.lab]
}

resource "random_id" "storage" {
  count       = var.bucket_name == null ? 1 : 0
  byte_length = 6
}

resource "awscc_s3_bucket" "private" {
  bucket_name = var.bucket_name != null ? var.bucket_name : "upc-c02-${var.lab_id}-${data.aws_caller_identity.current.account_id}-${random_id.storage[0].hex}"

  public_access_block_configuration = {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
  ownership_controls = {
    rules = [{ object_ownership = "BucketOwnerEnforced" }]
  }
  bucket_encryption = {
    server_side_encryption_configuration = [{
      server_side_encryption_by_default = { sse_algorithm = "AES256" }
    }]
  }
  tags = [
    { key = "Name", value = local.name },
    { key = "course", value = "upc-2026" },
    { key = "lab", value = "cloud-02" },
    { key = "lab_id", value = var.lab_id },
  ]
}
