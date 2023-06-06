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

# create private subnet
module "network" {
  source         = "../modules/network"
  project_id     = var.project_id
  region         = var.region
  cluster_prefix = var.cluster_prefix
}

# [START gke_standard_private_regional_primary_cluster]
module "kafka_cluster" {
  source                   = "../modules/beta-private-cluster"
  project_id               = var.project_id
  name                     = "${var.cluster_prefix}-cluster"
  regional                 = true
  region                   = var.region
  network                  = module.network.network_name
  subnetwork               = module.network.subnet_name
  ip_range_pods            = "k8s-pod-range"
  ip_range_services        = "k8s-service-range"
  create_service_account   = false
  enable_private_endpoint  = false
  enable_private_nodes     = true
  master_ipv4_cidr_block   = "172.16.0.0/28"
  network_policy           = true
  logging_enabled_components = ["SYSTEM_COMPONENTS","WORKLOADS"]
  monitoring_enabled_components = ["SYSTEM_COMPONENTS"]
  enable_cost_allocation = true
  cluster_autoscaling = {
    "autoscaling_profile": "OPTIMIZE_UTILIZATION",
    "enabled" : true,
    "gpu_resources" : [],
    "min_cpu_cores" : 15,
    "min_memory_gb" : 60,
    "max_cpu_cores" : 30,
    "max_memory_gb" : 120,
  }
  monitoring_enable_managed_prometheus = true
  gke_backup_agent_config = true

  node_pools = [
    {
      name            = "pool-system"
      disk_size_gb    = 10
      disk_type       = "pd-standard"
      autoscaling     = false
      max_surge       = 1
      max_unavailable = 0
      machine_type    = "e2-medium"
      auto_repair     = true
    },
    {
      name            = "pool-kafka"
      disk_size_gb    = 10
      disk_type       = "pd-standard"
      autoscaling     = true
      min_count       = 1
      max_count       = 2
      max_surge       = 1
      max_unavailable = 0
      machine_type    = "e2-standard-2"
      auto_repair     = true
    },
    {
      name            = "pool-zookeeper"
      disk_size_gb    = 10
      disk_type       = "pd-standard"
      autoscaling     = true
      min_count       = 1
      max_count       = 2
      max_surge       = 1
      max_unavailable = 0
      machine_type    = "e2-standard-2"
      auto_repair     = true
    },
  ]
  node_pools_labels = {
    all = {}
    pool-kafka = {
      "app.stateful/component" = "kafka-broker"
    }
    pool-zookeeper = {
      "app.stateful/component" = "zookeeper"
    }
  }
  node_pools_taints = {
    all = []
    pool-kafka = [
      {
        key    = "app.stateful/component"
        value  = "kafka-broker"
        effect = "NO_SCHEDULE"
      },
    ],
    pool-zookeeper = [
      {
        key    = "app.stateful/component"
        value  = "zookeeper"
        effect = "NO_SCHEDULE"
      },
    ],
  }
 gce_pd_csi_driver = true
}

output "kubernetes_cluster_host" {
  value       = module.kafka_cluster.endpoint
  sensitive   = true
  description = "GKE Cluster Host"
}

output "kubectl_connection_command" {
  value       = "gcloud container clusters get-credentials ${var.project_id}-kafka-cluster --region ${var.region}"
  description = "Connection command"
}
# [END gke_standard_private_regional_backup_cluster]

