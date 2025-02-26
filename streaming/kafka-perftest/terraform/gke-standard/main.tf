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

data "google_service_account" "default" {
  account_id = "343408765424-compute@developer.gserviceaccount.com"
}

# [START gke_streaming_kafka_standard_private_regional_cluster]
module "kafka_cluster" {
  source         = "../modules/cluster"
  project_id     = var.project_id
  region         = var.region
  zones          = var.zones
  cluster_prefix = var.cluster_prefix
  network        = "${var.cluster_prefix}-vpc"
  subnetwork     = "${var.cluster_prefix}-private-subnet"


  node_pools = [
    {
      name               = "pool-kafka"
      disk_size_gb       = 20
      disk_type          = "hyperdisk-balanced"
      image_type         = "UBUNTU_CONTAINERD"
      autoscaling        = true
      min_count          = 1
      max_count          = 1
      max_surge          = 1
      max_unavailable    = 0
      machine_type       = var.kafka_node_pool_instance_type
      auto_repair        = true
      enable_secure_boot = true
    },
    {
      name               = "pool-perftest"
      disk_size_gb       = 20
      disk_type          = "hyperdisk-balanced"
      image_type         = "UBUNTU_CONTAINERD"
      autoscaling        = true
      min_count          = 0
      max_count          = 1
      max_surge          = 1
      max_unavailable    = 0
      machine_type       = var.perftest_node_pool_instance_type
      auto_repair        = true
      enable_secure_boot = true
    },
    # {
    #   name               = "pool-general"
    #   disk_size_gb       = 20
    #   disk_type          = "hyperdisk-balanced"
    #   image_type         = "UBUNTU_CONTAINERD"
    #   autoscaling        = true
    #   min_count          = 0
    #   max_count          = 1
    #   max_surge          = 1
    #   max_unavailable    = 0
    #   machine_type       = "c4-standard-8"
    #   auto_repair        = true
    #   enable_secure_boot = true
    # }

  ]
  node_pools_labels = {
    all = {}
    pool-kafka = {
      "app.stateful/component" = "kafka-broker"
    },
    pool-perftest = {
      "app.stateful/component" = "perftest"
    }
  }
  node_pools_taints = {
    all = []
    pool-kafka = [
      {
        key    = "app.stateful/component"
        value  = "kafka-broker"
        effect = "NO_SCHEDULE"
      }
    ]
    # pool-perftest = [
    #   {
    #     key    = "app.stateful/component"
    #     value  = "kafka-perftest"
    #     effect = "NO_SCHEDULE"
    #   }
    # ]
  }
}

output "kubectl_connection_command" {
  value       = "gcloud container clusters get-credentials ${var.cluster_prefix}-cluster --region ${var.region}"
  description = "Connection command"
}
# [END gke_streaming_kafka_standard_private_regional_cluster]

