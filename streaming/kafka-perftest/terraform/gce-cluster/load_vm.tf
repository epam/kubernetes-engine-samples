resource "google_compute_instance" "kafka_load_generator" {
  count        = 3
  name         = "kafka-load-generator-${count.index}"
  machine_type = "c4-highmem-2"
  zone         = "us-central1-a"

  # Boot disk
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20                      # Boot disk size in GB
      type  = "hyperdisk-balanced"
      provisioned_iops       = "3000"
      provisioned_throughput = "700"
    }
  }

  # Internal-only network interface (same VPC as the Kafka cluster)
  network_interface {
    nic_type    = "GVNIC"
    queue_count = 0
    subnetwork  = "projects/hl2-gogl-wopt-t1iylu/regions/us-central1/subnetworks/kafka-private-subnet"
  }

  labels = {
    goog-ec-src = "vm_add-tf"
  }

  service_account {
    email  = "343408765424-compute@developer.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/compute", "https://www.googleapis.com/auth/devstorage.read_write", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
  }

  metadata = {
    enable-oslogin : "TRUE"
  }  

  # Add metadata startup script for preparing the test VM
  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -e

    LOG_FILE="/var/log/startup-script.log"
    KAFKA_DONE_FILE="/opt/kafka/setup-done"

    exec > >(tee -a "$${LOG_FILE}") 2>&1

  # Check if Kafka is already configured
  if [ -f "$${KAFKA_DONE_FILE}" ]; then
    echo "$(date) Kafka is already configured. Skipping setup."
  else
    echo "$(date) Kafka is not configured. Beginning setup."

    echo "$(date) Starting Kafka load generator setup."

    # Waiting for 90 seconds for system setup to release all the locks
    sleep 90

    # Install OpenJDK 17
    echo "$(date) Installing OpenJDK 17."
    sudo apt update
    sudo apt install -y openjdk-17-jdk sysstat

    # Ops Agent installation
    curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
    sudo bash add-google-cloud-ops-agent-repo.sh --also-install

    # Download and install Kafka tools
    echo "$(date) Downloading Kafka tools."
    cd /tmp
    curl -O https://downloads.apache.org/kafka/3.9.0/kafka_2.13-3.9.0.tgz
    tar -xvf kafka_2.13-3.9.0.tgz
    sudo mv kafka_2.13-3.9.0 /opt/kafka

    # Add Kafka tools to the global PATH for all users
    echo "$(date) Adding Kafka tools to PATH globally."
    echo 'export PATH=$PATH:/opt/kafka/bin' | sudo tee /etc/profile.d/kafka.sh
    sudo chmod +x /etc/profile.d/kafka.sh

    echo "$(date) Kafka setup completed."

    # Mark setup as complete
    sudo touch "$${KAFKA_DONE_FILE}"
    echo "$(date) Setup marker file created at $${KAFKA_DONE_FILE}."
  fi
  echo "$(date) Metadata script execution completed."
  EOT

  tags = ["gce-kafka"] # Updated tag to match brokers
}