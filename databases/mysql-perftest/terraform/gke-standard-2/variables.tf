# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

variable "project_id" {
  description = "The project ID to host the cluster in"
  default     = ""
}

variable "region" {
  description = "The region to host the cluster in"
  default     = "us-central1"
}

variable "cluster_prefix" {
  description = "The prefix for all cluster resources"
  default     = "mysql"
}

variable "mysql_node_pool_instance_type" {
  description = "The VM instance type for mysql node pool"
  default     = "c4-standard-8"
}

variable "sysbench_node_pool_instance_type" {
  description = "The VM instance type for performance test node pool"
  default     = "c4-standard-8"
}

variable "zones" {
  default = ["us-central1-a", "us-central1-b", "us-central1-c"] # c4 and c4a-standard not available in "us-central1-f"
}

variable "mysql_boot_disk_type" {
  description = "Boot disk type for mysql node pool."
  default = "hyperdisk-balanced"
}
variable "sysbench_boot_disk_type" {
  description = "Boot disk type for mysql node pool."
  default = "hyperdisk-balanced"
}
variable "mysql_max_count" {
  description = "Maximum number of nodes per zone"
  default     = 3
}

variable "sysbench_max_count" {
  description = "Maximum number of nodes per zone"
  default     = 3
}

variable "mysql_image_type" {
  description = "Image type used on mysql nodes, possible values are COS_CONTAINERD, UBUNTU_CONTAINERD"
  default = "COS_CONTAINERD"
}

variable "tuned_mysql_image_type" {
  description = "Image type used on tuned mysql nodes, possible values are COS_CONTAINERD, UBUNTU_CONTAINERD"
  default = "COS_CONTAINERD"
}

variable "datapath_provider" {
  description = "Datplane version, LEGACY_DATAPATH for v1, ADVANCED_DATAPATH for v2"
  default = "LEGACY_DATAPATH"
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the GKE master's IPv4 range"
  type        = string
}