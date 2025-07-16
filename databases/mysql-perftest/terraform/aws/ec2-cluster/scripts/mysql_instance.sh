#!/usr/bin/env bash
set -euo pipefail
 
###############################################################################
# Variables injected by Terraform (templatefile)
###############################################################################
INSTANCE_INDEX="${instance_index}"
 
DATA_DISK_DEVICE=$(lsblk -o NAME,SIZE,TYPE | awk '$2 == "500G" && $3 == "disk" {print $1}')
MYSQL_MOUNT="/var/lib/mysql"
 
CA_PEM='${ca_pem}'
SERVER_CERT_PEM='${server_cert_pem}'
SERVER_KEY_PEM='${server_key_pem}'
 
LOG_FILE="/var/log/mysql-setup.log"
MYSQL_DONE_FILE="/opt/mysql/setup-done"
 
exec > >(tee -a "$${LOG_FILE}") 2>&1
 
if [[ -f "$${MYSQL_DONE_FILE}" ]]; then
  echo "$(date) MySQL is already configured. Skipping setup."
  exit 0
fi
 
echo "$(date) MySQL is not configured. Beginning setup."
 
###############################################################################
# Disk preparation
###############################################################################
echo "[INFO] Formatting & mounting $${DATA_DISK_DEVICE}"
if ! mountpoint -q "$${MYSQL_MOUNT}"; then
  mkdir -p "$${MYSQL_MOUNT}"
  mkfs.xfs -i size=512 -f "/dev/$${DATA_DISK_DEVICE}" || true
  mount -t xfs -o defaults "/dev/$${DATA_DISK_DEVICE}" "$${MYSQL_MOUNT}"
  echo "/dev/$${DATA_DISK_DEVICE} $${MYSQL_MOUNT} xfs defaults,nofail 0 2" >> /etc/fstab
fi
 
###############################################################################
# Base packages & MySQL 8.0
###############################################################################
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y wget gnupg lsb-release
 
wget -q https://dev.mysql.com/get/mysql-apt-config_0.8.34-1_all.deb
DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.34-1_all.deb
sed -i 's/mysql-8.4/mysql-8.0/' /etc/apt/sources.list.d/mysql.list || true
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server
 
systemctl stop mysql
 
###############################################################################
# SSL material
###############################################################################
echo "[INFO] Writing SSL certificates"
mkdir -p "$${MYSQL_MOUNT}/ssl" && chmod 700 "$${MYSQL_MOUNT}/ssl"
echo "$${CA_PEM}"        > "$${MYSQL_MOUNT}/ssl/ca.pem"
echo "$${SERVER_CERT_PEM}" > "$${MYSQL_MOUNT}/ssl/server-cert.pem"
echo "$${SERVER_KEY_PEM}"  > "$${MYSQL_MOUNT}/ssl/server-key.pem"
chown mysql:mysql "$${MYSQL_MOUNT}"/ssl/*.pem
chmod 600 "$${MYSQL_MOUNT}/ssl/server-key.pem"
chmod 644 "$${MYSQL_MOUNT}/ssl/server-cert.pem" "$${MYSQL_MOUNT}/ssl/ca.pem"
 
###############################################################################
# MySQL configuration
###############################################################################
CNF=/etc/mysql/mysql.conf.d/mysqld.cnf
if [[ "$${INSTANCE_INDEX}" == "1" ]]; then
  cat >"$${CNF}" <<'EOF'
[mysqld]
bind-address = 0.0.0.0
ssl-ca = ca.pem
ssl-cert = server-cert.pem
ssl-key = server-key.pem
require_secure_transport = ON
log_error = /var/log/mysql/error.log
secure_file_priv = ""
innodb_buffer_pool_size = 100G
innodb_redo_log_capacity = 120G
 
# general
max_connections = 4000
table_open_cache = 8000
table_open_cache_instances = 16
max_prepared_stmt_count = 512000
back_log = 1500
skip-character-set-client-handshake
performance_schema = OFF
skip_log_bin = 1
transaction_isolation = REPEATABLE-READ
 
# files
innodb_file_per_table
innodb_log_file_size = 1024M
innodb_log_files_in_group = 32
innodb_open_files = 4000
 
# buffers
innodb_buffer_pool_instances = 16
innodb_log_buffer_size = 64M
 
# tune
innodb_doublewrite = 0
innodb_thread_concurrency = 0
innodb_flush_log_at_trx_commit = 1
innodb_max_dirty_pages_pct = 90
innodb_max_dirty_pages_pct_lwm = 10
 
join_buffer_size = 32K
sort_buffer_size = 32K
innodb_use_native_aio = 1
innodb_stats_persistent = 1
innodb_spin_wait_delay = 6
 
innodb_max_purge_lag_delay = 300000
innodb_max_purge_lag = 0
innodb_flush_method = O_DIRECT
innodb_checksum_algorithm = none
innodb_io_capacity = 10000
innodb_io_capacity_max = 40000
innodb_lru_scan_depth = 9000
innodb_change_buffering = none
innodb_read_only = 0
innodb_page_cleaners = 16
innodb_undo_log_truncate = off
 
# perf special
innodb_adaptive_flushing = 1
innodb_flush_neighbors = 0
innodb_read_io_threads = 16
innodb_write_io_threads = 16
innodb_purge_threads = 4
innodb_adaptive_hash_index = 0
EOF
else
  cat >"$${CNF}" <<'EOF'
[mysqld]
bind-address = 0.0.0.0
ssl-ca = ca.pem
ssl-cert = server-cert.pem
ssl-key = server-key.pem
require_secure_transport = ON
log_error = /var/log/mysql/error.log
secure_file_priv = ""
max_connections = 4100
back_log = 1500
table_open_cache = 200000
table_open_cache_instances = 32
max_prepared_stmt_count = 512000
skip-name-resolve
skip-character-set-client-handshake
performance_schema = 1
binlog_row_image = MINIMAL
 
# InnoDB settings
innodb_buffer_pool_instances = 16
innodb_buffer_pool_size = 100G
innodb_redo_log_capacity = 120G
innodb_io_capacity = 80000
innodb_io_capacity_max = 1600000
innodb_page_cleaners = 16
innodb_purge_threads = 4
innodb_lru_scan_depth = 1024
innodb_adaptive_flushing_lwm = 10
innodb_flushing_avg_loops = 30
innodb_flush_method = O_DIRECT_NO_FSYNC
innodb_numa_interleave = 1
innodb_change_buffering = none
innodb_adaptive_hash_index = 0
 
# Durability
innodb_doublewrite = 1
innodb_doublewrite_pages = 64
innodb_doublewrite_files = 2
innodb_flush_log_at_trx_commit = 1
innodb_buffer_pool_load_at_startup = 0
innodb_buffer_pool_dump_at_shutdown = 0
 
# Logging
slow-query-log = 1
long_query_time = 10
EOF
fi
 
###############################################################################
# Kernel & service limits
###############################################################################
sysctl -w net.ipv4.tcp_fin_timeout=5 \
         net.ipv4.tcp_tw_reuse=1 \
         net.ipv4.ip_local_port_range="4000 65000" \
         net.ipv4.tcp_max_syn_backlog=65535 \
         net.core.netdev_max_backlog=65535 \
         net.core.somaxconn=65535 \
         vm.swappiness=1 \
         vm.dirty_background_ratio=5 \
         vm.dirty_ratio=15
 
mkdir -p /etc/systemd/system/mysql.service.d
cat >/etc/systemd/system/mysql.service.d/override.conf <<'EOL'
[Service]
LimitNOFILE=200000
EOL
 
systemctl daemon-reload
systemctl start mysql
systemctl enable mysql
 
###############################################################################
# Benchmarking user
###############################################################################
sleep 20
mysql -u root <<'SQL'
CREATE DATABASE IF NOT EXISTS test;
CREATE USER IF NOT EXISTS 'bench_user'@'%' IDENTIFIED BY 'Bench123_StrongPass';
GRANT ALL PRIVILEGES ON test.* TO 'bench_user'@'%';
FLUSH PRIVILEGES;
SQL
 
mkdir -p /opt/mysql && touch "$${MYSQL_DONE_FILE}"
echo "$(date) MySQL server setup complete."
