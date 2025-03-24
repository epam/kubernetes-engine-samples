Content-Type: multipart/mixed; boundary="//"
MIME-Version: 1.0
 
--//
Content-Type: text/cloud-config; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment;
 filename="cloud-config.txt"
 
#cloud-config
cloud_final_modules:
- [scripts-user, always]
--//
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="userdata.txt"

#!/bin/bash -x

LOG_FILE="/var/log/startup-script.log"
KAFKA_DONE_FILE="/opt/kafka/setup-done"
KAFKA_ROOT="/mnt/kafka-data"
LOG_DIR="/mnt/kafka-data/kafka-logs"

# BROKER_ID=$(index(tolist(data.aws_subnets.kafka_private.ids), each.value))
DISK_DEVICE=$(lsblk -o NAME,SIZE,TYPE | awk '$2 == "300G" && $3 == "disk" {print $1}')

exec > >(tee -a "$LOG_FILE") 2>&1

echo "$(date) Starting Kafka initialization script for broker ID: ${BROKER_ID}"

if [ -f "$KAFKA_DONE_FILE" ]; then
  echo "$(date) Kafka broker ID ${BROKER_ID} is already configured. Clearing logs for a fresh start."

  # Clear Kafka logs to reset topic data and metadata
  echo "$(date) Cleaning Kafka logs directory..."
  sudo rm -rf "$LOG_DIR"/*
  sudo rm -rf "$KAFKA_ROOT/meta.properties"

  echo "$(date) Re-formatting Kafka metadata directory..."
  /opt/kafka/bin/kafka-storage.sh format \
    --config /opt/kafka/config/server.properties \
    --cluster-id "$CLUSTER_ID"

else
  echo "$(date) Kafka broker ID ${BROKER_ID} is not configured. Setting up Kafka..."

  # Create kafka system user
  if ! id -u kafka >/dev/null 2>&1; then
      sudo useradd -r -m -d /home/kafka -s /sbin/nologin kafka
  fi

  sleep 300 # Optional: Allow time for system to stabilize

  # Install dependencies
  echo "$(date) Installing OpenJDK 17."
  sudo apt update
  sudo apt install -y openjdk-17-jdk xfsprogs sysstat

  # Format and mount the Kafka data disk
  echo "$(date) Preparing Kafka disk..."
  if [ -z "$DISK_DEVICE" ]; then
      echo "$(date) ERROR: No disk available for Kafka data storage!" | tee -a "$LOG_FILE"
      exit 1
  fi

  if ! sudo file -s /dev/$DISK_DEVICE | grep -q ext4; then
      echo "$(date) Formatting disk /dev/$DISK_DEVICE as EXT4..."
      sudo mkfs.ext4 -m 0 -F /dev/$DISK_DEVICE
    #   sudo mkfs.xfs -f /dev/$DISK_DEVICE
  fi

  if ! mount | grep -q "$KAFKA_ROOT"; then
      sudo mkdir -p "$KAFKA_ROOT"
      sudo mount -o defaults /dev/$DISK_DEVICE "$KAFKA_ROOT"
      echo "/dev/$DISK_DEVICE $KAFKA_ROOT ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
    #   echo "/dev/$DISK_DEVICE $KAFKA_ROOT xfs defaults,nofail 0 2" | sudo tee -a /etc/fstab
  fi

  echo "$(date) Preparing Kafka log directory..."
  sudo mkdir -p "$LOG_DIR"
  sudo chown -R kafka:kafka "$KAFKA_ROOT" "$LOG_DIR"
  sudo chmod -R 700 "$KAFKA_ROOT" "$LOG_DIR"

  # Download and extract Kafka
  echo "$(date) Downloading Kafka..."
  cd /tmp
  curl -O https://downloads.apache.org/kafka/3.9.0/kafka_2.13-3.9.0.tgz
  if [ $? -ne 0 ]; then
      echo "$(date) ERROR: Failed to download Kafka tarball!" | tee -a "$LOG_FILE"
      exit 1
  fi
  tar -xvzf kafka_2.13-3.9.0.tgz
  sudo mv kafka_2.13-3.9.0 /opt/kafka

  # Configure Kafka broker
  BROKER_IP=$(hostname -I | awk '{print $1}')
  BROKER_HOSTNAME="${BROKER_ID}"
  BROKER_INDEX=$(echo $BROKER_HOSTNAME | cut -d'-' -f2 | cut -d'.' -f1)

  echo "$(date) Configuring Kafka broker..."
  cat <<EOF | sudo tee /opt/kafka/config/server.properties
broker.id=$BROKER_INDEX
log.dirs=$LOG_DIR
listeners=PLAINTEXT://$BROKER_IP:9092,CONTROLLER://$BROKER_IP:9093
advertised.listeners=PLAINTEXT://$BROKER_HOSTNAME:9092
node.id=$BROKER_INDEX
controller.quorum.voters=0@broker-0.kafka-perf.test:9093,1@broker-1.kafka-perf.test:9093,2@broker-2.kafka-perf.test:9093
controller.listener.names=CONTROLLER
process.roles=broker,controller
num.network.threads=3
num.io.threads=8
cluster.id=${CLUSTER_ID}
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000

default.replication.factor=3
min.insync.replicas=2
EOF

  echo "$(date) Formatting Kafka metadata directory..."
  /opt/kafka/bin/kafka-storage.sh format \
    --config /opt/kafka/config/server.properties \
    --cluster-id "$CLUSTER_ID"

  echo "$(date) Kafka setup completed for broker ID ${BROKER_ID}."
  touch "$KAFKA_DONE_FILE"
fi

echo "$(date) Starting Kafka broker service..."
nohup /opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties >/tmp/kafka.log 2>&1 &