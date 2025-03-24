# NAT Gateway specific resources (for cost optimization)

data "aws_subnet" "nat_subnet" {
  filter {
    name   = "tag:Name"
    values = ["nat-subnet"]
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc" # Allocate Elastic IP for NAT Gateway
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = data.aws_subnet.nat_subnet.id # NAT Gateway resides in its own dedicated subnet

  tags = {
    Name = "nat-gateway"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = data.aws_vpc.kafka_vpc.id

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
  for_each       = toset(data.aws_subnets.kafka_private.ids)
  subnet_id      = each.value
  route_table_id = aws_route_table.private_route_table.id
}