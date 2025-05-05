#!/bin/bash
set -e

LOG_FILE="/var/log/sysbench-setup.log"
MYSQL_DONE_FILE="/opt/mysql/setup-done"
exec > >(tee -a "${LOG_FILE}") 2>&1

if [ -f "${MYSQL_DONE_FILE}" ]; then
    echo "$(date) MySQL is already configured. Skipping setup."
  else
    echo "$(date) MySQL is not configured. Beginning setup."

    echo "$(date) Starting MySQL load generator setup."

    # Waiting for 90 seconds for system setup to release all the locks
    sleep 90

    echo "[INFO] Installing Sysbench and dependencies"
    apt update
    apt install -y sysbench mysql-client 

    # Ops Agent installation
    echo "[INFO] Installing Cloud Ops Agent"
    curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
    sudo bash add-google-cloud-ops-agent-repo.sh --also-install

    echo "$(date) MySQL setup completed."

    # Mark setup as complete
    sudo mkdir /opt/mysql
    sudo touch "${MYSQL_DONE_FILE}"
    echo "$(date) Setup marker file created at ${MYSQL_DONE_FILE}."
fi
echo "$(date) Metadata script execution completed."


