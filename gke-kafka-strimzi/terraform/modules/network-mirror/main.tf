#Copyright 2023 Google LLC

#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at

#    http://www.apache.org/licenses/LICENSE-2.0

#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

// [START vpc_multi_region_network]
module "gcp-network" {
  source  = "terraform-google-modules/network/google"
  version = "< 8.0.0"

  project_id   = var.project_id
  network_name = "${var.cluster_prefix}-vpc"

  subnets = [
    {
      subnet_name           = "${var.cluster_prefix}-source-private-subnet"
      subnet_ip             = "10.10.0.0/24"
      subnet_region         = "us-central1"
      subnet_private_access = true
      subnet_flow_logs      = "true"
    },
    {
      subnet_name           = "${var.cluster_prefix}-target-private-subnet"
      subnet_ip             = "10.11.0.0/24"
      subnet_region         = "us-east1"
      subnet_private_access = true
      subnet_flow_logs      = "true"
    }
  ]

  secondary_ranges = {
    ("${var.cluster_prefix}-source-private-subnet") = [
      {
        range_name    = "k8s-pod-range"
        ip_cidr_range = "10.48.0.0/20"
      },
      {
        range_name    = "k8s-service-range"
        ip_cidr_range = "10.52.0.0/20"
      },
    ],
    ("${var.cluster_prefix}-target-private-subnet") = [
      {
        range_name    = "k8s-pod-range"
        ip_cidr_range = "10.54.0.0/20"
      },
      {
        range_name    = "k8s-service-range"
        ip_cidr_range = "10.56.0.0/20"
      },
    ]
  }
}

module "firewall_rules" {
  source       = "terraform-google-modules/network/google//modules/firewall-rules"
  project_id   = var.project_id
  network_name = module.gcp-network.network_name

  rules = [{
    name                    = "allow-kafka-ingress"
    description             = "Interconnection between Kafka clusters with TLS auth"
    direction               = "INGRESS"
    destination_ranges      = ["10.52.0.0/20","10.56.0.0/20"]
    source_ranges           = ["10.48.0.0/20","10.54.0.0/20"]
    allow = [{
      protocol = "tcp"
      ports    = ["9093"]
    },
    {
      protocol = "tcp"
      ports    = ["80"]
    },
    ]
    deny = []
  }]
}

output "network_name" {
  value = module.gcp-network.network_name
}

output "source_subnet_name" {
  value = module.gcp-network.subnets_names[0]
}

output "target_subnet_name" {
  value = module.gcp-network.subnets_names[1]
}

// [END vpc_multi_region_network]

# [START cloudnat_simple_create]
module "source_cloud_router" {
  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 5.0"
  project = var.project_id 
  name    = "${var.cluster_prefix}-source-nat-router"
  network = module.gcp-network.network_name
  region  = "us-central1"
  nats = [{
    name = "${var.cluster_prefix}-source-nat"
  }]
}

module "target_cloud_router" {
  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 5.0"
  project = var.project_id 
  name    = "${var.cluster_prefix}-target-nat-router"
  network = module.gcp-network.network_name
  region  = "us-east1"
  nats = [{
    name = "${var.cluster_prefix}-target-nat"
  }]
}

# [END cloudnat_simple_create]
