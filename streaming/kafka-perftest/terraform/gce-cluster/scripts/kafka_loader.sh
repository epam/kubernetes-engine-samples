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

    # Install OpenJDK 17
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