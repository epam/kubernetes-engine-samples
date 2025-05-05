#!/bin/bash
set -e

LOG_FILE="/var/log/mysql-setup.log"
MYSQL_DONE_FILE="/opt/mysql/setup-done"
exec > >(tee -a "${LOG_FILE}") 2>&1

if [ -f "${MYSQL_DONE_FILE}" ]; then
    echo "$(date) MySQL is already configured. Skipping setup."
else
  echo "$(date) MySQL is not configured. Beginning setup."
  echo "[INFO] Installing MySQL 8.4"

  apt update
  DEBIAN_FRONTEND=noninteractive apt install -y wget gnupg lsb-release

  wget https://dev.mysql.com/get/mysql-apt-config_0.8.34-1_all.deb
  DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.34-1_all.deb
  apt update
  DEBIAN_FRONTEND=noninteractive apt install -y mysql-server

  echo "[INFO] Configuring MySQL 8.4"

  cat <<EOF > /etc/mysql/mysql.conf.d/mysqld.cnf
  [mysqld]
  bind-address = 0.0.0.0
  log_error = /var/log/mysql/error.log
  secure_file_priv = ""
EOF

  systemctl restart mysql
  systemctl enable mysql

  # Wait for MySQL to come up
  sleep 20

  echo "[INFO] Creating benchmarking user"

  BENCH_USER="bench_user"
  BENCH_PASS="Bench123_StrongPass"
  BENCH_DB="test"

  mysql -u root <<MYSQL_EOF
  CREATE DATABASE IF NOT EXISTS ${BENCH_DB};
  CREATE USER IF NOT EXISTS '${BENCH_USER}'@'%' IDENTIFIED BY '${BENCH_PASS}';
  GRANT ALL PRIVILEGES ON ${BENCH_DB}.* TO '${BENCH_USER}'@'%';
  FLUSH PRIVILEGES;
MYSQL_EOF

  echo "[INFO] MySQL benchmarking user created and privileges granted."

  # Mark setup as complete
  sudo mkdir /opt/mysql
  sudo touch "${MYSQL_DONE_FILE}"
  echo "$(date) Setup marker file created at ${MYSQL_DONE_FILE}."
fi
echo "$(date) Metadata script execution completed."