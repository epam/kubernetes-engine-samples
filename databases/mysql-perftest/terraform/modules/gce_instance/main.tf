data "google_compute_network" "target_vpc" {
  name = var.vpc_name
}

resource "google_compute_firewall" "service_firewall" {
  count   = var.create_firewall && var.firewall_name != null ? 1 : 0
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
  # count                  = var.use_data_disk ? var.instance_count : 0
  # name                   = var.instance_count > 1 ? "${var.name_prefix}-${count.index}-disk" : "${var.name_prefix}-disk"
  
  # 10 disks when this module is called for server-1 (name_prefix ends in “-1”),
  # otherwise exactly 1.
  count = var.use_data_disk ? (startswith(var.name_prefix, "mysql-server-1") ? 10 : 1) : 0

  # names:  mysql-server-1-data-disk-0 … -9  OR  mysql-server-0-data-disk
  name = startswith(var.name_prefix, "mysql-server-1") ? format("mysql-server-1-data-disk-%d", count.index) : format("%s-data-disk", var.name_prefix)
  
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
  name         = var.instance_count > 1 ? "${var.name_prefix}-${count.index}" : var.name_prefix
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
    # when use_data_disk = true:
    #   – server-1 gets 10 pre-created disks
    #   – every other VM gets 1
    for_each = var.use_data_disk ? {
      for d in google_compute_disk.persistent_disks : d.name => d
    } : {}

    iterator = disk

    content {
      source      = disk.value.id
      device_name = disk.value.name
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
