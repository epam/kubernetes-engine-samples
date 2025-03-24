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
  sudo snap install aws-cli --classic
  sudo apt install -y openjdk-17-jdk sysstat

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