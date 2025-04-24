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
  network        = module.network.network_name
  subnetwork     = module.network.subnet_name
  datapath_provider = var.datapath_provider

  node_pools = [
    {
      name               = "pool-kafka"
      disk_size_gb       = 20
      disk_type          = var.kafka_boot_disk_type
      image_type         = var.kafka_image_type
      autoscaling        = true
      min_count          = 1
      max_count          = var.kafka_max_count
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
      min_count          = 1
      max_count          = var.perftest_max_count
      max_surge          = 1
      max_unavailable    = 0
      machine_type       = var.perftest_node_pool_instance_type
      auto_repair        = true
      enable_secure_boot = true
    },
    {
      name               = "kafka-tuned"
      disk_size_gb       = 20
      disk_type          = var.kafka_boot_disk_type
      image_type         = var.tuned_kafka_image_type
      autoscaling        = true
      min_count          = 1
      max_count          = var.kafka_max_count
      max_surge          = 1
      max_unavailable    = 0
      machine_type       = var.kafka_node_pool_instance_type
      auto_repair        = true
      enable_secure_boot = true
    },

  ]
  node_pools_labels = {
    all = {}
    pool-kafka = {
      "app.stateful/component" = "kafka-broker"
    },
    pool-perftest = {
      "app.stateful/component" = "perftest"
    },
    kafka-tuned = {
      "app.stateful/component" = "kafka-tuned"
    },
  }
  node_pools_taints = {
    all = []
    pool-kafka = [
      {
        key    = "app.stateful/component"
        value  = "kafka-broker"
        effect = "NO_SCHEDULE"
      },
    ]
    kafka-tuned = [
      {
        key    = "app.stateful/component"
        value  = "kafka-tuned"
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
  node_pools_linux_node_configs_sysctls = {
    all = {}
    default-node-pool = {}
  }
  node_pools_cgroup_mode=  {
    all               = "CGROUP_MODE_UNSPECIFIED"
    kafka-tuned       = "CGROUP_MODE_UNSPECIFIED"
    pool-kafka        = "CGROUP_MODE_UNSPECIFIED"
    pool-perftest     = "CGROUP_MODE_UNSPECIFIED"
  }
  
}

output "kubectl_connection_command" {
  value       = "gcloud container clusters get-credentials ${var.cluster_prefix}-cluster --region ${var.region}"
  description = "Connection command"
}
# [END gke_streaming_kafka_standard_private_regional_cluster]

