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





# [START gke_databases_mysql_standard_private_regional_cluster]
module "mysql_cluster" {
  source                   = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version                  = "~> 36.0.2"
  project_id               = var.project_id
  name                     = "${var.cluster_prefix}-cluster"
  regional                 = true
  region                   = var.region
  zones                    = var.zones
  network                  = var.network
  subnetwork               = var.subnetwork
  ip_range_pods            = "k8s-pod-range"
  ip_range_services        = "k8s-service-range"
  create_service_account   = false
  enable_private_endpoint  = false
  enable_private_nodes     = true
  master_ipv4_cidr_block   = var.master_ipv4_cidr_block
  # network_policy           = true
  logging_enabled_components = ["SYSTEM_COMPONENTS","WORKLOADS"]
  monitoring_enabled_components = ["SYSTEM_COMPONENTS"]
  enable_cost_allocation = true
  deletion_protection = false
  initial_node_count = 1
  remove_default_node_pool = true
  datapath_provider = var.datapath_provider
  # dns_cache      = true
  master_authorized_networks = [
    {
      cidr_block = "85.223.209.0/24"
      display_name = "EPAM"
    },
    {
      cidr_block = "35.235.240.0/20"
      display_name = "Google CloudShell"
    }
   ]

  kubernetes_version  = "1.32"

  cluster_resource_labels = {
    name      = "${var.cluster_prefix}-cluster"
    component = "${var.cluster_prefix}-operator"
  }

  monitoring_enable_managed_prometheus = true
  gke_backup_agent_config = true


  node_pools        = var.node_pools
  node_pools_labels = var.node_pools_labels
  node_pools_taints = var.node_pools_taints
  node_pools_linux_node_configs_sysctls = var.node_pools_linux_node_configs_sysctls
  node_pools_cgroup_mode = var.node_pools_cgroup_mode
  gce_pd_csi_driver = true
}
# [END gke_databases_mysql_standard_private_regional_cluster]

