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
  default     = "hl2-gogl-wopt-t1iylu"
}

variable "region" {
  description = "The region to host the cluster in"
  default     = "us-central1"
}

variable "zones" {
  description = "List of zones in the region to deploy brokers across"
  type        = list(string)
  default     = ["us-central1-a", "us-central1-b", "us-central1-c"]
}

variable "machine_type" {
  description = "Machine type for Kafka brokers"
  type        = string
  default     = "c4-standard-8"
}

variable "os_image" {
  description = "Image OS type for Kafka brokers"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}