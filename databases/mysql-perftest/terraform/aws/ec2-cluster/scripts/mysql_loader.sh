#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Variables injected by Terraform
###############################################################################
MYSQL_HOST="${target_server}"
MYSQL_HOST_DNS="${target_server}.mysql-perf.test"
THREADS="${thread_count}"
MYSQL_MACHINE_TYPE="${target_machine_type}"
S3_BUCKET="${s3_bucket}"
S3_SUBDIR="${s3_subdir}"

CA_PEM='${ca_pem}'
CLIENT_CERT_PEM='${client_cert_pem}'
CLIENT_KEY_PEM='${client_key_pem}'

LOG_FILE="/var/log/sysbench-setup.log"
MYSQL_DONE_FILE="/opt/mysql/setup-done"
BENCH_LOG="/opt/$${MYSQL_HOST}-sysbench-$${THREADS}.txt"

exec > >(tee -a "$${LOG_FILE}") 2>&1

if [[ ! -f "$${MYSQL_DONE_FILE}" ]]; then
  echo "$(date) Starting first-time loader setup."

  # Wait for system initialization
  sleep 90

  echo "[INFO] Installing dependencies"
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
      mysql-client make automake libtool pkg-config libaio-dev \
      libmysqlclient-dev libssl-dev git
  snap install aws-cli --classic

  echo "[INFO] Cloning & building Sysbench"
  git clone --depth 1 https://github.com/akopytov/sysbench /opt/tmp/sysbench
  (cd /opt/tmp/sysbench && ./autogen.sh && ./configure && make -j && make install)
  echo 'export PATH=$PATH:/usr/local/bin' > /etc/profile.d/sysbench.sh
  chmod +x /etc/profile.d/sysbench.sh

  echo "[INFO] Writing SSL PEMs"
  mkdir -p /etc/mysql/ssl && chmod 700 /etc/mysql/ssl
  echo "$${CA_PEM}"         > /etc/mysql/ssl/ca.pem
  echo "$${CLIENT_CERT_PEM}" > /etc/mysql/ssl/client-cert.pem
  echo "$${CLIENT_KEY_PEM}"  > /etc/mysql/ssl/client-key.pem
  chmod 600 /etc/mysql/ssl/client-key.pem
  chmod 644 /etc/mysql/ssl/ca.pem /etc/mysql/ssl/client-cert.pem

  echo "[INFO] Setting kernel parameters & ulimits"
  echo -e "* soft nofile 200000\n* hard nofile 200000" > /etc/security/limits.d/sysbench-nofile.conf
  ulimit -n 200000
  sysctl -w net.ipv4.tcp_fin_timeout=5 \
           net.ipv4.tcp_tw_reuse=1 \
           net.ipv4.ip_local_port_range="4000 65000" \
           net.ipv4.tcp_max_syn_backlog=65535 \
           net.core.netdev_max_backlog=65535 \
           net.core.somaxconn=65535 \
           vm.swappiness=1 \
           vm.dirty_background_ratio=5 \
           vm.dirty_ratio=15
  [[ $(grep -c pam_limits.so /etc/pam.d/common-session) -eq 0 ]] && \
      echo "session required pam_limits.so" >> /etc/pam.d/common-session

  mkdir -p /opt/mysql && touch "$${MYSQL_DONE_FILE}"
fi

###############################################################################
# Wait for the target MySQL server to be fully ready
###############################################################################
sleep 420

case "$${MYSQL_HOST}" in
  mysql-server-0)
    OPTIMIZATION="none"  # raw server
    ;;
  mysql-server-1)
    OPTIMIZATION="optconfig-p3rfconfig-40000"  # optimized server
    ;;
  *)
    OPTIMIZATION="unknown"
    ;;
esac

###############################################################################
# Begin benchmarking
###############################################################################
BENCH_DB="test"
BENCH_USER="bench_user"
BENCH_PASS="Bench123_StrongPass"
TABLES=8
TABLE_SIZE=50000000
DURATION=300
RUNS=3

mkdir -p /opt
{
  echo "Sysbench Benchmark Results - $(date)"
  echo "Benchmark target MySQL server: $${MYSQL_HOST}"
  echo "Benchmark thread count:        $${THREADS}"
  echo "Benchmark target machine type: $${MYSQL_MACHINE_TYPE}"
  echo "Optimization attempt:          $${OPTIMIZATION}"
  echo ""
} > "$${BENCH_LOG}"

echo "[INFO] Preparing database" | tee -a "$${BENCH_LOG}"
sysbench oltp_read_write \
  --table-size=$${TABLE_SIZE} \
  --tables=$${TABLES} \
  --db-driver=mysql \
  --mysql-host=$${MYSQL_HOST_DNS} \
  --mysql-db=$${BENCH_DB} \
  --mysql-user=$${BENCH_USER} \
  --mysql-password=$${BENCH_PASS} \
  --mysql-ssl=REQUIRED \
  --mysql-ignore-errors=all \
  --threads=8 \
  --db-ps-mode=disable \
  --skip_trx=on \
  prepare >> "$${BENCH_LOG}" 2>&1

for i in $(seq 1 $${RUNS}); do
  echo -e "\n===== RUN $${i} with THREADS=$${THREADS} at $(date) =====" | tee -a "$${BENCH_LOG}"
  sysbench oltp_read_write \
    --table-size=$${TABLE_SIZE} \
    --tables=$${TABLES} \
    --db-driver=mysql \
    --mysql-host=$${MYSQL_HOST_DNS} \
    --mysql-db=$${BENCH_DB} \
    --mysql-user=$${BENCH_USER} \
    --mysql-password=$${BENCH_PASS} \
    --mysql-ssl=REQUIRED \
    --mysql-ignore-errors=all \
    --threads=$${THREADS} \
    --time=$${DURATION} \
    --db-ps-mode=disable \
    --skip_trx=on \
    --report-interval=1 \
    run >> "$${BENCH_LOG}" 2>&1
done

echo "[INFO] Cleaning up test tables" | tee -a "$${BENCH_LOG}"
sysbench oltp_read_write \
  --table-size=$${TABLE_SIZE} \
  --tables=$${TABLES} \
  --mysql-host=$${MYSQL_HOST_DNS} \
  --mysql-db=$${BENCH_DB} \
  --mysql-user=$${BENCH_USER} \
  --mysql-password=$${BENCH_PASS} \
  --mysql-ssl=REQUIRED \
  --threads=8 \
  cleanup >> "$${BENCH_LOG}" 2>&1

###############################################################################
# Upload results to S3
###############################################################################
TIMESTAMP=$(date +'%Y_%m_%d_%H_%M_%S')
aws s3 cp "$${BENCH_LOG}" "s3://$${S3_BUCKET}/$${S3_SUBDIR}/$${OPTIMIZATION}_$${MYSQL_MACHINE_TYPE}_$(basename "$${BENCH_LOG}")"
echo "$(date) Sysbench benchmark complete."