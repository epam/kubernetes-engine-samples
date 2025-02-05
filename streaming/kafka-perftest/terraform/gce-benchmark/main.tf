provider "google" {
  
  project     = var.project_id
  region      = var.region
}

# This code is compatible with Terraform 4.25.0 and versions that are backwards compatible to 4.25.0.
# For information about validating this Terraform code, see https://developer.hashicorp.com/terraform/tutorials/gcp-get-started/google-cloud-platform-build#format-and-validate-the-configuration

resource "google_compute_instance" "kafka-perftest" {
  boot_disk {
    auto_delete = true
    device_name = "kafka-perftest"

    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/ubuntu-2404-noble-amd64-v20250130"
      size  = 20
      type  = "hyperdisk-balanced"
    }

    mode = "READ_WRITE"
  }

  can_ip_forward      = false
  deletion_protection = false
  enable_display      = false

  labels = {
    goog-ec-src = "vm_add-tf"
  }

  machine_type = "c4-standard-4"
  name         = "kafka-perftest"

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }

    nic_type    = "GVNIC"
    queue_count = 0
    stack_type  = "IPV4_ONLY"
    subnetwork  = "projects/hl2-gogl-wopt-t1iylu/regions/us-central1/subnetworks/kafka-private-subnet"
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  service_account {
    email  = "343408765424-compute@developer.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }

  zone = "us-central1-b"

  metadata = {
 
    // Adding a startup script
    startup-script = <<-EOF
      #!/bin/bash
      sudo apt update
      sudo apt install -y openjdk-17-jdk
      java -version
      wget https://dlcdn.apache.org/kafka/3.9.0/kafka_2.13-3.9.0.tgz
      tar -xzf kafka_2.13-3.9.0.tgz
      rm kafka_2.13-3.9.0.tgz
      mv /kafka_2.13-3.9.0 /opt/kafka
    EOF
  }
}

