resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name    = var.name
    account = "AWS Academy"
  }
}

resource "aws_subnet" "public_az_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_a
  availability_zone       = format("%sa", var.region)
  map_public_ip_on_launch = true
  private_dns_hostname_type_on_launch = "ip-name"

  tags = {
    Name    = format("%s-public-az-a-net", aws_vpc.main.tags.Name)
    vpc     = aws_vpc.main.id
    account = "AWS Academy"
  }
}

resource "aws_subnet" "public_az_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_b
  availability_zone       = format("%sb", var.region)
  map_public_ip_on_launch = true
  private_dns_hostname_type_on_launch = "ip-name"

  tags = {
    Name    = format("%s-public-az-b-net", aws_vpc.main.tags.Name)
    vpc     = aws_vpc.main.id
    account = "AWS Academy"
  }
}

resource "aws_subnet" "public_az_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_c
  availability_zone       = format("%sc", var.region)
  map_public_ip_on_launch = true
  private_dns_hostname_type_on_launch = "ip-name"

  tags = {
    Name    = format("%s-public-az-c-net", aws_vpc.main.tags.Name)
    vpc     = aws_vpc.main.id
    account = "AWS Academy"
  }
}

resource "aws_subnet" "private_az_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_a
  availability_zone = format("%sa", var.region)
  private_dns_hostname_type_on_launch = "ip-name"

  tags = {
    Name    = format("%s-private-az-a-net", aws_vpc.main.tags.Name)
    vpc     = aws_vpc.main.id
    account = "AWS Academy"
  }
}

resource "aws_subnet" "private_az_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_b
  availability_zone = format("%sb", var.region)
  private_dns_hostname_type_on_launch = "ip-name"

  tags = {
    Name    = format("%s-private-az-b-net", aws_vpc.main.tags.Name)
    vpc     = aws_vpc.main.id
    account = "AWS Academy"
  }
}

resource "aws_subnet" "private_az_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_c
  availability_zone = format("%sc", var.region)
  private_dns_hostname_type_on_launch = "ip-name"

  tags = {
    Name    = format("%s-private-az-c-net", aws_vpc.main.tags.Name)
    vpc     = aws_vpc.main.id
    account = "AWS Academy"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = format("%s-gw", var.name)
    vpc     = aws_vpc.main.id
    account = "AWS Academy"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = format("%s-sg", aws_vpc.main.tags.Name)
    vpc     = aws_vpc.main.id
    account = "AWS Academy"
  }
}

resource "aws_default_route_table" "main" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  # route {
  #   cidr_block = "${aws_vpc.main.cidr_block}"
  #   gateway_id = "${aws_internet_gateway.main.id}"
  # }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.main.id
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = format("%s-rt", var.name)
    vpc     = aws_vpc.main.id
    account = "AWS Academy"
  }
}
