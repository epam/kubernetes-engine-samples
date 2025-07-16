provider "aws" {
  region = var.region
}

data "local_file" "ca" {
  filename = "${path.module}/certs/ca.pem"
}

data "local_file" "server_cert" {
  filename = "${path.module}/certs/server-cert.pem"
}

data "local_file" "server_key" {
  filename = "${path.module}/certs/server-key.pem"
}

data "local_file" "client_cert" {
  filename = "${path.module}/certs/client-cert.pem"
}

data "local_file" "client_key" {
  filename = "${path.module}/certs/client-key.pem"
}
 

# Look-ups
data "aws_vpc" "mysql_vpc" {
  filter { 
    name = "tag:Name" 
    values = ["mysql-vpc"] 
  }
}

data "aws_subnets" "mysql_private" {
  filter { 
    name = "vpc-id" 
    values = [data.aws_vpc.mysql_vpc.id] 
  }
    tags = { 
      Tier = "private" 
    }
}

data "aws_security_group" "mysql_sg" {
  filter { 
    name = "group-name" 
    values = ["allow-mysql-ports"] 
  }
}

# ─── AWS-specific extras (kept from original) ───────────────────
resource "random_uuid" "mysql_cluster_id" {}   # may be used by init scripts

resource "aws_route53_zone" "private_dns" {
  name = "mysql-perf.test."
  vpc  { 
    vpc_id = data.aws_vpc.mysql_vpc.id 
  }
}

# ─── Helper maps ────────────────────────────────────────────────
locals {
  pair_ids         = toset(["0","1"])
  loader_thread_map = {                       # mirrors GCE example
    0 = 512
    1 = 512
  }
}

# ─── MySQL Servers (2) ──────────────────────────────────────────
module "mysql_servers" {
  for_each               = local.pair_ids

  source                 = "../modules/ec2_instance"

  ami_id                 = var.common_ami_id
  machine_type           = var.server_machine_type
  name_prefix            = "mysql-server-${each.key}"
  subnet_ids             = data.aws_subnets.mysql_private.ids
  security_group_ids     = [data.aws_security_group.mysql_sg.id]
  #key_name               = var.ssh_key_name

  use_data_disk          = true

#   iam_instance_profile   = aws_iam_instance_profile.ec2_bench_profile.name
  user_data_template     = "${path.module}/scripts/mysql_instance.sh"
  user_data_vars = {
    instance_index    = each.key
    ca_pem            = data.local_file.ca.content
    server_cert_pem   = data.local_file.server_cert.content
    server_key_pem    = data.local_file.server_key.content
  }

  depends_on = [
    aws_route_table_association.private_subnets_route_associations
  ]
 
}


# ─── MySQL Load Generators (2) ──────────────────────────────────
module "mysql_loaders" {
  for_each               = local.loader_thread_map

  source                 = "../modules/ec2_instance"

  ami_id                 = var.common_ami_id
  machine_type           = var.loader_machine_type
  name_prefix            = "mysql-loader-${each.key}"
  subnet_ids             = data.aws_subnets.mysql_private.ids
  security_group_ids     = [data.aws_security_group.mysql_sg.id]
  #key_name               = var.ssh_key_name

  use_data_disk          = false

#   iam_instance_profile   = aws_iam_instance_profile.ec2_bench_profile.name
  user_data_template     = "${path.module}/scripts/mysql_loader.sh"
  user_data_vars = {
    target_server       = "mysql-server-${each.key}"
    thread_count        = each.value
    target_machine_type = var.server_machine_type
    ca_pem              = data.local_file.ca.content
    client_cert_pem     = data.local_file.client_cert.content
    client_key_pem      = data.local_file.client_key.content
    s3_bucket           = var.s3_bucket_name
    s3_subdir           = "mysql/ec2"
  }
  depends_on = [
    aws_route_table_association.private_subnets_route_associations
  ]

}

# ─── Route 53 records for the two servers only ──────────────────
resource "aws_route53_record" "mysql_records" {
  for_each = module.mysql_servers

  zone_id = aws_route53_zone.private_dns.zone_id
  name    = "${each.value.name[0]}.mysql-perf.test"
  type    = "A"
  ttl     = 60
  records = [each.value.private_ip[0]]
}
 