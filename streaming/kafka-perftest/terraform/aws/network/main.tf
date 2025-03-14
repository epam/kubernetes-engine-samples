provider "aws" {
  region = "us-east-1"
}

# VPC creation
resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr

  enable_dns_hostnames = true

  tags = {
    Name = "kafka-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "kafka-ig"
  }
}

resource "aws_subnet" "private_subnets" {
  count                  = 3
  vpc_id                 = aws_vpc.main_vpc.id
  availability_zone      = element(var.availability_zones, count.index)
  cidr_block             = cidrsubnet("10.10.0.0/16", 8, count.index) # Creates 3 /24 subnets (`10.10.0.0/24`, `10.10.1.0/24`, etc.)

  tags = {
    Name = "kafka-private-subnet-${count.index}"
  }
}

resource "aws_subnet" "nat_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  availability_zone = "us-east-1c" # NAT Gateway will be placed in this AZ
  cidr_block        = "10.10.100.0/24" # Separate dedicated range (`10.10.100.0/24`)

  tags = {
    Name = "nat-subnet"
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc" # Allocate Elastic IP for NAT Gateway
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.nat_subnet.id # NAT Gateway resides in its own dedicated subnet

  tags = {
    Name = "nat-gateway"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  # Route for Internet egress-only traffic via NAT Gateway
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "private-route-table"
  }
}

# Associate the Route Table with each private subnet
resource "aws_route_table_association" "private_subnets_route_associations" {
  count          = 3
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_route_table.id
}

