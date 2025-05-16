variable "project_id" {
  type    = string
  default = "hl2-gogl-wopt-t1iylu"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "machine_type" {
  type    = string
  default = "c4-highmem-2"
}

variable "loader_machine_type" {
  type    = string
  default = "c4-highmem-2"
}

variable "os_image" {
  type    = string
  default = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

variable "loader_os_image" {
  type    = string
  default = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}
