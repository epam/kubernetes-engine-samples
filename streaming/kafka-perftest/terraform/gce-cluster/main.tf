provider "google" {
  
  project     = var.project_id
  region      = var.region
}

# Reference the existing VPC
data "google_compute_network" "kafka_vpc" {
  name = "kafka-vpc"
}

# Create 3 persistent disks, one for each Kafka broker
resource "google_compute_disk" "kafka-disks" {
  count = 3
  name  = "gce-kafka-disk-${count.index}"
  type  = "hyperdisk-balanced"  # Hyperdisk Balanced
  size  = 20                    # Size in GB
  zone  = var.zones[count.index]
}

resource "random_uuid" "kafka_cluster_id" {}

# Create Kafka broker instances
resource "google_compute_instance" "kafka" {
  count        = 3
  name         = "gce-kafka-broker-${count.index}"
  machine_type = var.machine_type
  zone         = var.zones[count.index] # Assign each broker to a different zone

  # Boot disk (Debian 12)
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20 # Boot disk size in GB
    }
  }

  can_ip_forward      = false
  deletion_protection = false
  enable_display      = false

  # Attach persistent Hyperdisk for Kafka logs
  attached_disk {
    source      = google_compute_disk.kafka-disks[count.index].id
    device_name = "kafka-data-disk-${count.index}"
  }

  # Internal-only network interface
  network_interface {
    nic_type    = "GVNIC"
    queue_count = 0
    subnetwork  = "projects/hl2-gogl-wopt-t1iylu/regions/us-central1/subnetworks/kafka-private-subnet"
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
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
  }

  metadata = {
    enable-oslogin : "TRUE"
    kafka-cluster-id = random_uuid.kafka_cluster_id.result
  }  

  # Startup script for Kafka setup
  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -e

    LOG_FILE="/var/log/startup-script.log"
    KAFKA_DONE_FILE="/opt/kafka/setup-done" # Marker file to indicate setup is complete
    LOG_DIR="/mnt/kafka-logs"

    exec > >(tee -a "$${LOG_FILE}") 2>&1

    echo "$(date) Starting metadata script."

    # Fetch the pre-generated cluster ID from metadata
    echo "$(date) Fetching Kafka cluster ID from instance metadata."
    CLUSTER_ID=$(curl -H "Metadata-Flavor: Google" \
      http://metadata.google.internal/computeMetadata/v1/instance/attributes/kafka-cluster-id)
    echo "$(date) Retrieved cluster ID: $${CLUSTER_ID}"

    # Check if Kafka is already configured
    if [ -f "$${KAFKA_DONE_FILE}" ]; then
      echo "$(date) Kafka is already configured. Skipping setup steps."
    else
      echo "$(date) Kafka is not configured. Beginning setup."

      # Install dependencies (OpenJDK 17)
      echo "$(date) Installing OpenJDK 17."
      sudo apt-get update
      sudo apt-get install -y openjdk-17-jdk

      # Mount Kafka logs disk
      echo "$(date) Preparing the disk for Kafka logs."
      sudo mkdir -p $${LOG_DIR}
      sudo mkfs.ext4 -m 0 -F /dev/disk/by-id/google-kafka-data-disk-${count.index} || true
      sudo mount -o discard,defaults /dev/disk/by-id/google-kafka-data-disk-${count.index} $${LOG_DIR}
      echo "/dev/disk/by-id/google-kafka-data-disk-${count.index} $${LOG_DIR} ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

      # Download and extract Kafka
      echo "$(date) Downloading and setting up Kafka."
      cd /tmp
      curl -O https://downloads.apache.org/kafka/3.9.0/kafka_2.13-3.9.0.tgz
      tar -xvf kafka_2.13-3.9.0.tgz
      sudo mv kafka_2.13-3.9.0 /opt/kafka

      # Configure Kafka broker (server.properties) BEFORE running kafka-storage.sh
      echo "$(date) Configuring Kafka broker."
      BROKER_IP=$(hostname -I | awk '{print $1}') # Use VM's internal IP
      BROKER_ID=${count.index}
      BROKER_HOSTNAME="gce-kafka-broker-$${BROKER_ID}"

      cat <<EOF | sudo tee /opt/kafka/config/server.properties
broker.id=$${BROKER_ID}
log.dirs=$${LOG_DIR}
listeners=PLAINTEXT://$${BROKER_IP}:9092,CONTROLLER://$${BROKER_IP}:9093
advertised.listeners=PLAINTEXT://$${BROKER_HOSTNAME}:9092
node.id=$${BROKER_ID}
controller.quorum.voters=0@gce-kafka-broker-0:9093,1@gce-kafka-broker-1:9093,2@gce-kafka-broker-2:9093
controller.listener.names=CONTROLLER
process.roles=broker,controller
num.network.threads=3
num.io.threads=8
cluster.id=$${CLUSTER_ID}
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
EOF

      echo "$(date) Kafka broker configuration written to server.properties."

      # Format the KRaft metadata directory (meta.properties) AFTER server.properties is prepared
      if [ ! -f "$${LOG_DIR}/meta.properties" ]; then
        echo "$(date) Formatting metadata directory for broker node ${count.index}."
        /opt/kafka/bin/kafka-storage.sh format \
          --config /opt/kafka/config/server.properties \
          --cluster-id $${CLUSTER_ID}
      else
        echo "$(date) Metadata directory already formatted for broker node ${count.index}."
      fi

      echo "$(date) Kafka setup completed."

      # Mark setup as complete
      sudo touch "$${KAFKA_DONE_FILE}"
      echo "$(date) Setup marker file created at $${KAFKA_DONE_FILE}."
    fi

    # Always (re)start Kafka on VM boot
    echo "$(date) Starting Kafka service."
    nohup /opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties > /tmp/kafka.log 2>&1 &

    echo "$(date) Metadata script execution completed."
  EOT

  tags = ["kafka"]
}

# Outputs for internal IPs of Kafka brokers
output "kafka_internal_ips" {
  value = [for instance in google_compute_instance.kafka: instance.network_interface[0].network_ip]
}
