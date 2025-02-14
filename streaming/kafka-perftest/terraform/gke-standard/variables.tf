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
  default     = "kafka"
}

variable "kafka_node_pool_instance_type" {
  description = "The VM instance type for kafka node pool"
  default     = "c4-standard-8"
}

variable "perftest_node_pool_instance_type" {
  description = "The VM instance type for performance test node pool"
  default     = "c4-standard-8"
}


