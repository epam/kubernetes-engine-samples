provider "google" {
  project = var.project_id
  region  = var.region
}

# Load SSL cert/key files from disk
data "local_file" "ca" {
  filename = "${path.module}/certs/ca.pem"
}

data "local_file" "server_cert" {
  filename = "${path.module}/certs/server-cert.pem"
}

data "local_file" "server_key" {
  filename = "${path.module}/certs/server-key.pem"
}

data "local_file" "client_cert" {
  filename = "${path.module}/certs/client-cert.pem"
}

data "local_file" "client_key" {
  filename = "${path.module}/certs/client-key.pem"
}

module "mysql_instance" {
  for_each = toset(["0", "1"])

  source                  = "../modules/gce_instance"
  zones                   = ["us-central1-a"]
  machine_type            = var.machine_type
  os_image                = var.os_image
  instance_count          = 1
  name_prefix             = "mysql-server-${each.key}"
  instance_tags           = ["gce-mysql"]
  create_firewall         = each.key == "0" ? true : false
  firewall_name           = "mysql-fw"
  allowed_ports           = ["3306"]
  vpc_name                = "mysql-vpc"
  subnetwork_self_link    = "projects/${var.project_id}/regions/us-central1/subnetworks/mysql-private-subnet"
  metadata_script_path    = "${path.module}/scripts/mysql_instance.sh"
  use_data_disk           = true
  data_disk_type          = "hyperdisk-balanced"
  data_disk_iops          = 12000
  data_disk_throughput    = 180
  data_disk_size          = 500

  additional_metadata = {
    "ca-pem"          = data.local_file.ca.content
    "server-cert-pem" = data.local_file.server_cert.content
    "server-key-pem"  = data.local_file.server_key.content
    "instance-index"  = each.key
  }

}

locals {
  loader_thread_map = {
    0 = 512
    1 = 512
    # 2 = 128
    # 3 = 256
    # 4 = 512
    # 5 = 1024
    # 6 = 2048
  }
}

module "mysql_loader" {
  for_each = local.loader_thread_map

  source                  = "../modules/gce_instance"
  zones                   = ["us-central1-a"]
  machine_type            = var.loader_machine_type
  os_image                = var.loader_os_image
  instance_count          = 1
  name_prefix             = "mysql-loadgen-${each.key}"
  instance_tags           = ["gce-mysql"]
  firewall_name           = null
  allowed_ports           = []
  vpc_name                = "mysql-vpc"
  subnetwork_self_link    = "projects/${var.project_id}/regions/us-central1/subnetworks/mysql-private-subnet"
  metadata_script_path    = "${path.module}/scripts/mysql_loader.sh"
  boot_disk_type          = startswith(var.loader_machine_type, "n2-") ? "pd-balanced" : "hyperdisk-balanced"
  use_data_disk           = false

  additional_metadata = {
    "ca-pem"              = data.local_file.ca.content
    "client-cert-pem"     = data.local_file.client_cert.content
    "client-key-pem"      = data.local_file.client_key.content
    "target-machine-type" = var.machine_type
    "target-server-host"  = "mysql-server-${each.key}"
    "thread-count"        = tostring(each.value)
  }
 
}
