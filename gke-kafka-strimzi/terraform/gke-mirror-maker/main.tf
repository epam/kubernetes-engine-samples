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
# google_client_config and kubernetes provider must be explicitly specified like the following.
data "google_client_config" "default" {}

# create private subnets for two clusters
module "network" {
  source         = "../modules/network-mirror"
  project_id     = var.project_id
  cluster_prefix = var.cluster_prefix
}

# [START gke_standard_private_regional_clusters]
module "source_kafka_cluster" {
  source                   = "../modules/cluster-mirror"
  project_id               = var.project_id
  region                   = "us-central1"
  cluster_prefix           = "${var.cluster_prefix}-source"
  network                  = module.network.network_name
  subnetwork               = module.network.source_subnet_name
  master_ipv4_cidr_block   = "172.16.0.0/28"
}

module "target_kafka_cluster" {
  source                   = "../modules/cluster-mirror"
  project_id               = var.project_id
  region                   = "us-east1"
  cluster_prefix           = "${var.cluster_prefix}-target"
  network                  = module.network.network_name
  subnetwork               = module.network.target_subnet_name
  master_ipv4_cidr_block   = "172.17.0.0/28"
}

output "kubectl_connection_command_source" {
  value       = "gcloud container clusters get-credentials ${var.cluster_prefix}-source-cluster --region us-central1"
  description = "Connection command for source cluster"
}

output "kubectl_connection_command_target" {
  value       = "gcloud container clusters get-credentials ${var.cluster_prefix}-target-cluster --region us-east1"
  description = "Connection command for source cluster"
}

# [END gke_standard_private_regional_cluster]

