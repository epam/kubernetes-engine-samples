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

# [START gke_streaming_mysql_standard_private_regional_cluster]
module "mysql_cluster" {
  source         = "../modules/cluster"
  project_id     = var.project_id
  region         = var.region
  zones          = var.zones
  cluster_prefix = var.cluster_prefix
  network        = "mysql-vpc"
  subnetwork     = "mysql-private-subnet"
  datapath_provider = var.datapath_provider
  master_ipv4_cidr_block = var.master_ipv4_cidr_block

  node_pools = [
    {
      name               = "pool-mysql"
      disk_size_gb       = 70
      disk_type          = var.mysql_boot_disk_type
      image_type         = var.mysql_image_type
      autoscaling        = true
      min_count          = var.mysql_max_count
      max_count          = var.mysql_max_count
      max_surge          = 1
      max_unavailable    = 0
      machine_type       = var.mysql_node_pool_instance_type
      auto_repair        = true
      enable_secure_boot = true
    },
    {
      name               = "pool-sysbench"
      disk_size_gb       = 70
      disk_type          = var.sysbench_boot_disk_type
      image_type         = "COS_CONTAINERD"
      autoscaling        = true
      min_count          = var.sysbench_max_count
      max_count          = var.sysbench_max_count
      max_surge          = 1
      max_unavailable    = 0
      machine_type       = var.sysbench_node_pool_instance_type
      auto_repair        = true
      enable_secure_boot = true
    },
    {
      name               = "mysql-tuned"
      disk_size_gb       = 70
      disk_type          = var.mysql_boot_disk_type
      image_type         = var.tuned_mysql_image_type
      autoscaling        = true
      min_count          = var.mysql_max_count
      max_count          = var.mysql_max_count
      max_surge          = 1
      max_unavailable    = 0
      machine_type       = var.mysql_node_pool_instance_type
      auto_repair        = true
      enable_secure_boot = true
    },

  ]
  node_pools_labels = {
    all = {}
    pool-mysql = {
      "app.stateful/component" = "mysql"
    },
    pool-sysbench = {
      "app.stateful/component" = "sysbench"
    },
    mysql-tuned = {
      "app.stateful/component" = "mysql-tuned"
    },
  }
  node_pools_taints = {
    all = []
    pool-mysql = [
      {
        key    = "app.stateful/component"
        value  = "mysql"
        effect = "NO_SCHEDULE"
      },
    ]
    mysql-tuned = [
      {
        key    = "app.stateful/component"
        value  = "mysql-tuned"
        effect = "NO_SCHEDULE"
      }
    ]
    # pool-sysbench = [
    #   {
    #     key    = "app.stateful/component"
    #     value  = "mysql-sysbench"
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
    mysql-tuned       = "CGROUP_MODE_UNSPECIFIED"
    pool-mysql        = "CGROUP_MODE_UNSPECIFIED"
    pool-sysbench     = "CGROUP_MODE_UNSPECIFIED"
  }
  
}

output "kubectl_connection_command" {
  value       = "gcloud container clusters get-credentials ${var.cluster_prefix}-cluster --region ${var.region}"
  description = "Connection command"
}
# [END gke_streaming_mysql_standard_private_regional_cluster]

