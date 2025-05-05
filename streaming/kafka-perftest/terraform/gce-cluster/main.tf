module "kafka_brokers" {
  source                  = "../modules/gce-instance"
  project_id              = var.project_id
  region                  = "us-central1"
  zones                   = ["us-central1-a", "us-central1-b", "us-central1-c"]
  machine_type            = var.machine_type
  os_image                = var.os_image
  instance_count          = 1
  name_prefix             = "gce-kafka-broker"
  instance_tags           = ["gce-kafka"]
  firewall_name           = "kafka-firewall"
  allowed_ports           = ["9092", "9093"]
  vpc_name                = "kafka-vpc"
  subnetwork_self_link    = "projects/${var.project_id}/regions/us-central1/subnetworks/kafka-private-subnet"
  metadata_script_path    = "${path.module}/scripts/kafka_instance.sh"
  use_data_disk           = true
  data_disk_type          = "hyperdisk-balanced"
  data_disk_iops          = 6000
  data_disk_throughput    = 700
  data_disk_size          = 300
}

module "kafka_loader" {
  source                  = "../modules/gce-instance"
  project_id              = var.project_id
  region                  = "us-central1"
  zones                   = ["us-central1-a"]
  machine_type            = var.machine_type
  os_image                = var.os_image
  instance_count          = 1
  name_prefix             = "kafka-loadgen"
  instance_tags           = ["gce-kafka"]
  firewall_name           = null
  allowed_ports           = []
  vpc_name                = "kafka-vpc"
  subnetwork_self_link    = "projects/${var.project_id}/regions/us-central1/subnetworks/kafka-private-subnet"
  metadata_script_path    = "${path.module}/scripts/kafka_loader.sh"
  use_data_disk           = false
}
 