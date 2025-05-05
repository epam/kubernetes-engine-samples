module "mysql_instance" {
  source                  = "../modules/gce_instance"
  project_id              = var.project_id
  region                  = "us-central1"
  zones                   = ["us-central1-a"]
  machine_type            = var.machine_type
  os_image                = var.os_image
  instance_count          = 1
  name_prefix             = "mysql-server"
  instance_tags           = ["gce-mysql"]
  firewall_name           = "mysql-fw"
  allowed_ports           = ["3306"]
  vpc_name                = "mysql-vpc"
  subnetwork_self_link    = "projects/${var.project_id}/regions/us-central1/subnetworks/mysql-private-subnet"
  metadata_script_path    = "${path.module}/scripts/mysql_instance.sh"
  use_data_disk           = true
  data_disk_type          = "hyperdisk-balanced"
  data_disk_iops          = 3000
  data_disk_throughput    = 500
  data_disk_size          = 200
}

module "mysql_loader" {
  source                  = "../modules/gce_instance"
  project_id              = var.project_id
  region                  = "us-central1"
  zones                   = ["us-central1-a"]
  machine_type            = var.machine_type
  os_image                = var.os_image
  instance_count          = 1
  name_prefix             = "mysql-loadgen"
  instance_tags           = ["gce-mysql"]
  firewall_name           = null
  allowed_ports           = []
  vpc_name                = "mysql-vpc"
  subnetwork_self_link    = "projects/${var.project_id}/regions/us-central1/subnetworks/mysql-private-subnet"
  metadata_script_path    = "${path.module}/scripts/mysql_loader.sh"
  use_data_disk           = false
}

 