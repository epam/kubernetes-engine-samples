provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_compute_network" "target_vpc" {
  name = var.vpc_name
}

resource "google_compute_firewall" "service_firewall" {
  count   = var.firewall_name != null ? 1 : 0
  name    = var.firewall_name
  network = data.google_compute_network.target_vpc.self_link

  allow {
    protocol = "tcp"
    ports    = var.allowed_ports
  }

  source_tags = var.instance_tags
  target_tags = var.instance_tags
}


resource "google_compute_disk" "persistent_disks" {
  count                  = var.use_data_disk ? var.instance_count : 0
  name                   = "${var.name_prefix}-disk-${count.index}"
  type                   = var.data_disk_type
  provisioned_iops       = var.data_disk_iops
  provisioned_throughput = var.data_disk_throughput
  size                   = var.data_disk_size
  zone                   = var.zones[count.index % length(var.zones)]
}

resource "random_uuid" "cluster_id" {
  count = var.name_prefix == "gce-kafka-broker" ? 1 : 0
}

resource "google_compute_instance" "instance" {
  count        = var.instance_count
  name         = "${var.name_prefix}-${count.index}"
  machine_type = var.machine_type
  zone         = var.zones[count.index % length(var.zones)]

  boot_disk {
    initialize_params {
      image = var.os_image
      size  = var.boot_disk_size
      type  = var.boot_disk_type

      provisioned_iops       = var.boot_disk_type == "hyperdisk-balanced" && var.boot_disk_iops != null ? var.boot_disk_iops : null
      provisioned_throughput = var.boot_disk_type == "hyperdisk-balanced" && var.boot_disk_throughput != null ? var.boot_disk_throughput : null
    }
  }

  allow_stopping_for_update = true
  can_ip_forward            = false
  deletion_protection       = false
  enable_display            = false

  dynamic "attached_disk" {
    for_each = var.use_data_disk ? [1] : []
    content {
      source      = google_compute_disk.persistent_disks[count.index].id
      device_name = "${var.name_prefix}-data-disk-${count.index}"
    }
  }

  network_interface {
    nic_type    = "GVNIC"
    queue_count = 0
    subnetwork  = var.subnetwork_self_link
  }

  labels = {
    goog-ec-src = "vm_add-tf"
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }

  service_account {
    email  = "343408765424-compute@developer.gserviceaccount.com"
    scopes = [
      "https://www.googleapis.com/auth/devstorage.read_write",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append"
    ]
  }

  metadata = merge(
    {
      enable-oslogin = "TRUE"
    },
    var.name_prefix == "gce-kafka-broker" ? {
      kafka-cluster-id = random_uuid.cluster_id[0].result
    } : {},
    var.additional_metadata
  )

  metadata_startup_script = file(var.metadata_script_path)

  tags = var.instance_tags
}
