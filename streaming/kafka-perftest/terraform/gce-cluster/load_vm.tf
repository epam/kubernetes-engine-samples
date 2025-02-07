resource "google_compute_instance" "kafka_load_generator" {
  name         = "kafka-load-generator"
  machine_type = "c4-standard-4"
  zone         = "us-central1-a"

  # Boot disk
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12" # Debian 12 (same as Kafka brokers)
      size  = 20                      # Boot disk size in GB
      type  = "hyperdisk-balanced"
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
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
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

    # Install OpenJDK 17
    echo "$(date) Installing OpenJDK 17."
    sudo apt-get update
    sudo apt-get install -y openjdk-17-jdk

    # Download and install Kafka tools
    echo "$(date) Downloading Kafka tools."
    cd /tmp
    curl -O https://downloads.apache.org/kafka/3.9.0/kafka_2.13-3.9.0.tgz
    tar -xvf kafka_2.13-3.9.0.tgz
    sudo mv kafka_2.13-3.9.0 /opt/kafka

    # Add Kafka tools to the PATH
    echo 'export PATH=$PATH:/opt/kafka/bin' >> ~/.bashrc
    source ~/.bashrc

    echo "$(date) Kafka setup completed."

    # Mark setup as complete
    sudo touch "$${KAFKA_DONE_FILE}"
    echo "$(date) Setup marker file created at $${KAFKA_DONE_FILE}."
  fi
  echo "$(date) Metadata script execution completed."
  EOT

  tags = ["gce-kafka"] # Updated tag to match brokers
}