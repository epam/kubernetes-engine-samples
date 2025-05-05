#!/bin/bash
set -e

LOG_FILE="/var/log/startup-script.log"
KAFKA_DONE_FILE="/opt/kafka/setup-done"
KAFKA_ROOT="/mnt/kafka-data"
LOG_DIR="/mnt/kafka-data/kafka-logs"

exec > >(tee -a "${LOG_FILE}") 2>&1

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
echo "$(date) Retrieved cluster ID: ${CLUSTER_ID}"

if [ -f "${KAFKA_DONE_FILE}" ]; then
  echo "$(date) Kafka is already configured. Clearing logs for a fresh start."

  # Clear Kafka logs to reset topic data and metadata
  echo "$(date) Cleaning Kafka logs directory at ${LOG_DIR}."
  sudo rm -rf "${LOG_DIR}"/*
  sudo rm -rf "${KAFKA_ROOT}/meta.properties"

  echo "$(date) Re-formatting Kafka metadata directory."
  /opt/kafka/bin/kafka-storage.sh format \
    --config /opt/kafka/config/server.properties \
    --cluster-id "${CLUSTER_ID}"

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
  if ! mount | grep -q "${KAFKA_ROOT}"; then
    sudo mkdir -p ${KAFKA_ROOT}
    # sudo mkfs.ext4 -m 0 -F /dev/disk/by-id/google-kafka-data-disk-${count.index} || true
    sudo mkfs.xfs -f /dev/disk/by-id/google-kafka-data-disk-${count.index} || true
    sudo mount -o defaults /dev/disk/by-id/google-kafka-data-disk-${count.index} ${KAFKA_ROOT}
    # echo "/dev/disk/by-id/google-kafka-data-disk-${count.index} ${KAFKA_ROOT} ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
    echo "/dev/disk/by-id/google-kafka-data-disk-${count.index} ${KAFKA_ROOT} xfs defaults,nofail 0 2" | sudo tee -a /etc/fstab
  else
    echo "$(date) Disk is already mounted on ${KAFKA_ROOT}. Skipping disk formatting."
  fi

  # Prepare Kafka logs directory with proper ownership and permissions
  echo "$(date) Preparing Kafka logs directory."
  sudo mkdir -p "${LOG_DIR}"
  sudo chown -R kafka:kafka "${KAFKA_ROOT}"
  sudo chmod -R 700 "${KAFKA_ROOT}"
  sudo chown -R kafka:kafka "${LOG_DIR}"
  sudo chmod -R 700 "${LOG_DIR}"

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
  BROKER_HOSTNAME="gce-kafka-broker-${BROKER_ID}"
  cat <<EOF | sudo tee /opt/kafka/config/server.properties
broker.id=${BROKER_ID}
log.dirs=${LOG_DIR}
listeners=PLAINTEXT://${BROKER_IP}:9092,CONTROLLER://${BROKER_IP}:9093
advertised.listeners=PLAINTEXT://${BROKER_HOSTNAME}:9092
node.id=${BROKER_ID}
controller.listener.names=CONTROLLER
process.roles=broker,controller
num.network.threads=3
num.io.threads=8
cluster.id=${CLUSTER_ID}
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000

# 3 Brokers settings
# controller.quorum.voters=0@gce-kafka-broker-0:9093,1@gce-kafka-broker-1:9093,2@gce-kafka-broker-2:9093
# default.replication.factor=3
# offsets.topic.replication.factor=3
# min.insync.replicas=2

# Single Broker settings
controller.quorum.voters=0@gce-kafka-broker-0:9093
default.replication.factor=1
offsets.topic.replication.factor=1
min.insync.replicas=1
EOF

  # Format metadata directory
  echo "$(date) Formatting metadata directory for broker node ${count.index}."
  /opt/kafka/bin/kafka-storage.sh format \
    --config /opt/kafka/config/server.properties \
    --cluster-id "${CLUSTER_ID}"

  echo "$(date) Kafka setup completed."
  sudo touch "${KAFKA_DONE_FILE}"
  echo "$(date) Setup marker file created at ${KAFKA_DONE_FILE}."
fi

echo "$(date) Starting Kafka service."
nohup /opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties > /tmp/kafka.log 2>&1 &

echo "$(date) Metadata script execution completed."
 