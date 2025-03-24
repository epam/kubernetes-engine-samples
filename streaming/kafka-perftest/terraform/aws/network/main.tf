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
    Tier = "private"
  }
}

resource "aws_subnet" "nat_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  availability_zone = "us-east-1c" # NAT Gateway will be placed in this AZ
  cidr_block        = "10.10.100.0/24" # Separate dedicated range (`10.10.100.0/24`)

  tags = {
    Name = "nat-subnet"
    Tier = "public"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  # Route for traffic between NAT Gateway and Internet Gateway
  route {
    cidr_block     = "0.0.0.0/0"
    gateway_id     = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_subnets_route_associations" {
  subnet_id      = aws_subnet.nat_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Security Group for Kafka Brokers
resource "aws_security_group" "kafka_brokers" {
  name        = "allow-kafka-ports"
  description = "Open ports for inter-broker communication"
  vpc_id      = aws_vpc.main_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_kafka_ports" {
  security_group_id = aws_security_group.kafka_brokers.id
  cidr_ipv4         = aws_vpc.main_vpc.cidr_block
  ip_protocol       = "tcp"
  from_port         = 9092
  to_port           = 9093
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound" {
  security_group_id = aws_security_group.kafka_brokers.id
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

resource "aws_security_group" "iap_to_brokers" {
  name        = "allow-iap-brokers"
  description = "Open SSH for IAP-broker communication"
  vpc_id      = aws_vpc.main_vpc.id
}

resource "aws_vpc_security_group_egress_rule" "allow_iap_outbound" {
  security_group_id = aws_security_group.iap_to_brokers.id
  cidr_ipv4         = aws_vpc.main_vpc.cidr_block
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_iap_inbound" {
  security_group_id            = aws_security_group.kafka_brokers.id
  referenced_security_group_id = aws_security_group.iap_to_brokers.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_ec2_instance_connect_endpoint" "kafka_iap" {
  subnet_id          = aws_subnet.private_subnets.0.id
  security_group_ids = [aws_security_group.iap_to_brokers.id]
}
