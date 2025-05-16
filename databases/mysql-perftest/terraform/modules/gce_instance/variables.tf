variable "zones" {
  type = list(string)
}

variable "machine_type" {
  type = string
}

variable "os_image" {
  type = string
}

variable "instance_count" {
  type = number
}

variable "name_prefix" {
  type = string
}

variable "instance_tags" {
  type = list(string)
}

variable "firewall_name" {
  type    = string
  default = null
}

variable "create_firewall" {
  type        = bool
  default     = false
  description = "Whether to create the firewall rule or not"
}

variable "allowed_ports" {
  type    = list(string)
  default = []
}

variable "vpc_name" {
  type = string
}

variable "subnetwork_self_link" {
  type = string
}

variable "metadata_script_path" {
  type = string
}

variable "additional_metadata" {
  type    = map(string)
  default = {}
}

variable "use_data_disk" {
  type    = bool
  default = true
}

variable "data_disk_type" {
  type    = string
  default = "hyperdisk-balanced"
}

variable "data_disk_iops" {
  type    = number
  default = 6000
}

variable "data_disk_throughput" {
  type    = number
  default = 700
}

variable "data_disk_size" {
  type    = number
  default = 300
}

variable "boot_disk_type" {
  type    = string
  default = "hyperdisk-balanced"
}

variable "boot_disk_size" {
  type    = number
  default = 20
}

variable "boot_disk_iops" {
  type    = number
  default = null
}

variable "boot_disk_throughput" {
  type    = number
  default = null
}
