provider "google" {
  
  project     = var.project_id
  region      = var.region
}

# Reference the existing VPC
data "google_compute_network" "kafka_vpc" {
  name = "kafka-vpc"
}

resource "google_compute_firewall" "kafka-firewall" {
  name    = "kafka-firewall"
  network = data.google_compute_network.kafka_vpc.self_link # Reference "kafka-vpc"

  allow {
    protocol = "tcp"
    ports    = ["9092", "9093"] # Port 9092 (broker) and 9093 (controller communication)
  }

  source_tags = ["gce-kafka"] # Allow traffic only from other Kafka brokers tagged "gce-kafka"
  target_tags = ["gce-kafka"] # Apply this rule only to Kafka broker instances with "gce-kafka" tag
}

# Create 3 persistent disks, one for each Kafka broker
resource "google_compute_disk" "kafka-disks" {
  count                  = 1
  name                   = "gce-kafka-disk-${count.index}"
  type                   = "hyperdisk-balanced"  # Hyperdisk Balanced
  provisioned_iops       = "6000"
  provisioned_throughput = "700"
  size                   = 300                    # Size in GB
  zone                   = var.zones[count.index]
  # zone                   = "us-central1-a"
}

resource "random_uuid" "kafka_cluster_id" {}

# Create Kafka broker instances
resource "google_compute_instance" "kafka" {
  count        = 1
  name         = "gce-kafka-broker-${count.index}"
  machine_type = var.machine_type
  zone         = var.zones[count.index] # Assign each broker to a different zone
  # zone         = "us-central1-a"
  # Boot disk
  boot_disk {
    initialize_params {
      image = var.os_image
      size  = 20 # Boot disk size in GB
    }
  }
  
  allow_stopping_for_update = true
  can_ip_forward            = false
  deletion_protection       = false
  enable_display            = false

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
    scopes = ["https://www.googleapis.com/auth/devstorage.read_write", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
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
KAFKA_DONE_FILE="/opt/kafka/setup-done"
KAFKA_ROOT="/mnt/kafka-data"
LOG_DIR="/mnt/kafka-data/kafka-logs"

exec > >(tee -a "$${LOG_FILE}") 2>&1

echo "$(date) Starting metadata script."

# Determine OS type
OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release)

if ! id -u kafka >/dev/null 2>&1; then
    echo "$(date) Creating 'kafka' system user with no shell."

    if [[ $OS == *"CentOS"* ]]; then
        sudo useradd -r -m -d /home/kafka -s /sbin/nologin kafka
    else # Debian
        sudo useradd -r -m -d /home/kafka -s /usr/sbin/nologin kafka
    fi
else
    echo "$(date) 'kafka' system user already exists."
fi

# Fetch the pre-generated cluster ID from metadata
echo "$(date) Fetching Kafka cluster ID from instance metadata"
CLUSTER_ID=$(curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/kafka-cluster-id)
echo "$(date) Retrieved cluster ID: $${CLUSTER_ID}"

if [ -f "$${KAFKA_DONE_FILE}" ]; then
  echo "$(date) Kafka is already configured. Clearing logs for a fresh start."

  # Clear Kafka logs to reset topic data and metadata
  echo "$(date) Cleaning Kafka logs directory at $${LOG_DIR}."
  sudo rm -rf "$${LOG_DIR}"/*
  sudo rm -rf "$${KAFKA_ROOT}/meta.properties"

  echo "$(date) Re-formatting Kafka metadata directory."
  /opt/kafka/bin/kafka-storage.sh format \
    --config /opt/kafka/config/server.properties \
    --cluster-id "$${CLUSTER_ID}"

else
  echo "$(date) Kafka is not configured. Setting up Kafka from scratch."

  # Waiting for 90 seconds for system setup to release all locks
  sleep 90
  # Install dependencies
  echo "$(date) Installing OpenJDK 17."
  if [[ $OS == *"CentOS"* ]]; then
      sudo dnf upgrade -y
      sudo dnf install -y java-17-openjdk xfsprogs sysstat
  else # Debian
      sudo apt update
      sudo apt install -y openjdk-17-jdk xfsprogs sysstat
  fi

  # Ops Agent installation
  curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
  sudo bash add-google-cloud-ops-agent-repo.sh --also-install

  # Format and mount the Kafka disk (if not already prepared)
  echo "$(date) Preparing disk for Kafka data storage."
  if ! mount | grep -q "$${KAFKA_ROOT}"; then
    sudo mkdir -p $${KAFKA_ROOT}
    # sudo mkfs.ext4 -m 0 -F /dev/disk/by-id/google-kafka-data-disk-${count.index} || true
    sudo mkfs.xfs -f /dev/disk/by-id/google-kafka-data-disk-${count.index} || true
    sudo mount -o defaults /dev/disk/by-id/google-kafka-data-disk-${count.index} $${KAFKA_ROOT}
    # echo "/dev/disk/by-id/google-kafka-data-disk-${count.index} $${KAFKA_ROOT} ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
    echo "/dev/disk/by-id/google-kafka-data-disk-${count.index} $${KAFKA_ROOT} xfs defaults,nofail 0 2" | sudo tee -a /etc/fstab
  else
    echo "$(date) Disk is already mounted on $${KAFKA_ROOT}. Skipping disk formatting."
  fi

  # Prepare Kafka logs directory with proper ownership and permissions
  echo "$(date) Preparing Kafka logs directory."
  sudo mkdir -p "$${LOG_DIR}"
  sudo chown -R kafka:kafka "$${KAFKA_ROOT}"
  sudo chmod -R 700 "$${KAFKA_ROOT}"
  sudo chown -R kafka:kafka "$${LOG_DIR}"
  sudo chmod -R 700 "$${LOG_DIR}"

  # Download and set up Kafka
  echo "$(date) Downloading and setting up Kafka."
  cd /tmp
  curl -O https://downloads.apache.org/kafka/3.9.0/kafka_2.13-3.9.0.tgz
  tar -xvf kafka_2.13-3.9.0.tgz
  sudo mv kafka_2.13-3.9.0 /opt/kafka

  # Configure Kafka
  echo "$(date) Configuring Kafka broker."
  BROKER_IP=$(hostname -I | awk '{print $1}')
  BROKER_ID=${count.index}
  BROKER_HOSTNAME="gce-kafka-broker-$${BROKER_ID}"
  cat <<EOF | sudo tee /opt/kafka/config/server.properties
broker.id=$${BROKER_ID}
log.dirs=$${LOG_DIR}
listeners=PLAINTEXT://$${BROKER_IP}:9092,CONTROLLER://$${BROKER_IP}:9093
advertised.listeners=PLAINTEXT://$${BROKER_HOSTNAME}:9092
node.id=$${BROKER_ID}
controller.quorum.voters=0@gce-kafka-broker-0:9093
controller.listener.names=CONTROLLER
process.roles=broker,controller
num.network.threads=3
num.io.threads=8
cluster.id=$${CLUSTER_ID}
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000

default.replication.factor=1
offsets.topic.replication.factor=1
min.insync.replicas=1
EOF

  # Format metadata directory
  echo "$(date) Formatting metadata directory for broker node ${count.index}."
  /opt/kafka/bin/kafka-storage.sh format \
    --config /opt/kafka/config/server.properties \
    --cluster-id "$${CLUSTER_ID}"

  echo "$(date) Kafka setup completed."
  sudo touch "$${KAFKA_DONE_FILE}"
  echo "$(date) Setup marker file created at $${KAFKA_DONE_FILE}."
fi

# Increase fs.nr_open and make it persistent
echo "fs.nr_open = 1073741816" | tee /etc/sysctl.d/90-fd-limits.conf
sysctl -w fs.nr_open=1073741816
sysctl --system

echo "$(date) Starting Kafka service."
nohup /opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties > /tmp/kafka.log 2>&1 &

echo "$(date) Metadata script execution completed."
EOT

  tags = ["gce-kafka"]
}

# Outputs for internal IPs of Kafka brokers
output "kafka_internal_ips" {
  value = [for instance in google_compute_instance.kafka: instance.network_interface[0].network_ip]
}
