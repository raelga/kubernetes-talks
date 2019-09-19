resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name    = "${var.name}"
    account = "talks"
  }
}

resource "aws_subnet" "az1" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${aws_vpc.main.tags.Name}-az1-net"
    vpc     = "${aws_vpc.main.id}"
    account = "talks"
  }
}
resource "aws_subnet" "az2" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${aws_vpc.main.tags.Name}-az2-net"
    vpc     = "${aws_vpc.main.id}"
    account = "talks"
  }
}

resource "aws_subnet" "az3" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "${var.region}c"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${aws_vpc.main.tags.Name}-az3-net"
    vpc     = "${aws_vpc.main.id}"
    account = "talks"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name    = "${var.name}-gw"
    vpc     = "${aws_vpc.main.id}"
    account = "talks"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = "${aws_vpc.main.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${aws_vpc.main.tags.Name}-sg"
    vpc     = "${aws_vpc.main.id}"
    account = "talks"
  }
}

resource "aws_default_route_table" "main" {
  default_route_table_id = "${aws_vpc.main.default_route_table_id}"
  
  # route {
  #   cidr_block = "${aws_vpc.main.cidr_block}"
  #   gateway_id = "${aws_internet_gateway.main.id}"
  # }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = "${aws_internet_gateway.main.id}"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.main.id}"
  }

  tags = {
    Name    = "${var.name}-rt"
    vpc     = "${aws_vpc.main.id}"
    account = "talks"
  }
}
