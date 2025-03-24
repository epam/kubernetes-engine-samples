provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "kafka_vpc" {
  filter {
    name   = "tag:Name"
    values = ["kafka-vpc"]
  }
}

data "aws_subnets" "kafka_private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.kafka_vpc.id]
  }

  tags = {
    Tier = "private"
  }
}

data "aws_security_group" "brokers_sg" {
  filter {
    name   = "group-name"
    values = ["allow-kafka-ports"]
  }
}

# Generate a UUID for the Kafka Cluster
resource "random_uuid" "kafka_cluster_id" {}
 
# Create Kafka Broker Instances
resource "aws_instance" "kafka_brokers" {
  for_each               = toset(data.aws_subnets.kafka_private.ids)
  ami                    = var.ami_id                   
  instance_type          = var.machine_type                               
  subnet_id              = each.value                                  # Assign each broker to a different private subnet
  vpc_security_group_ids = [data.aws_security_group.brokers_sg.id]     # Use the same security group for all brokers

  # Root Volume Configuration
  root_block_device {
    volume_size           = 20                       # 20 GB size
    volume_type           = "gp3"                    # General Purpose SSD
    iops                  = 3000                     # IOPS for gp3
    throughput            = 125                      # Throughput in MB/s
    delete_on_termination = true                     # Remove on termination
  }

  # Additional Volume for Kafka Data
  ebs_block_device {
    device_name           = "/dev/sdb"
    volume_size           = 300                      # 300 GB for Kafka data
    volume_type           = "gp3"                    # gp3 for performance
    iops                  = 5000                     # Set high IOPS
    throughput            = 700                      # Set high throughput
    delete_on_termination = true                    
  }

  monitoring = true

  user_data = templatefile("./init.sh", {
    CLUSTER_ID = random_uuid.kafka_cluster_id.result,
    BROKER_ID  = "broker-${index(tolist(data.aws_subnets.kafka_private.ids), each.value)}.kafka-perf.test"
  })

  tags = {
    Name = "broker-${index(tolist(data.aws_subnets.kafka_private.ids), each.value)}"
  }
}

resource "aws_route53_zone" "private_dns" {
  name = "kafka-perf.test."
  vpc {
    vpc_id = data.aws_vpc.kafka_vpc.id
  }
}

resource "aws_route53_record" "kafka_records" {
  for_each = aws_instance.kafka_brokers # Reference the instances created earlier

  zone_id = aws_route53_zone.private_dns.zone_id
  name    = "${aws_instance.kafka_brokers[each.key].tags.Name}.kafka-perf.test" # Example: broker-0.kafka-perf.test
  type    = "A"
  ttl     = 60
  records = [each.value.private_ip] # Use the private IP of the corresponding instance
}