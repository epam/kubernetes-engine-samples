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

  echo "[INFO] Installing dependencies"
  apt update
  apt install -y mysql-client make automake libtool pkg-config libaio-dev libmysqlclient-dev libssl-dev
  echo "[INFO] Downloading and installing Sysbench"
  git clone https://github.com/akopytov/sysbench /opt/tmp/sysbench
  cd /opt/tmp/sysbench/ && ./autogen.sh && ./configure && make -j
  make install
  echo "[INFO] Add Sysbench to the global PATH for all users"
  echo 'export PATH=$PATH:/usr/local/bin' | tee /etc/profile.d/sysbench.sh
  chmod +x /etc/profile.d/sysbench.sh
  cd /tmp

  # Ops Agent installation
  echo "[INFO] Installing Cloud Ops Agent"
  curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
  sudo bash add-google-cloud-ops-agent-repo.sh --also-install

  echo "[INFO] Writing SSL certificates for sysbench from metadata"

  mkdir -p /etc/mysql/ssl
  chmod 700 /etc/mysql/ssl

  echo "$(curl -s -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/attributes/ca-pem)" > /etc/mysql/ssl/ca.pem
  echo "$(curl -s -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/attributes/client-cert-pem)" > /etc/mysql/ssl/client-cert.pem
  echo "$(curl -s -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/attributes/client-key-pem)" > /etc/mysql/ssl/client-key.pem

  chown root:root /etc/mysql/ssl/*.pem
  chmod 600 /etc/mysql/ssl/client-key.pem
  chmod 644 /etc/mysql/ssl/client-cert.pem /etc/mysql/ssl/ca.pem

  echo "$(date) MySQL setup completed."

  echo "[INFO] Setting ulimit for open files to 200000"

  cat <<EOF > /etc/security/limits.d/sysbench-nofile.conf
  * soft nofile 200000
  * hard nofile 200000
EOF

  echo "[INFO] Setting kernel to the same parameters as in GCP P3rf team scenario "
  sysctl -w net.ipv4.tcp_fin_timeout=5
  sysctl -w net.ipv4.tcp_tw_reuse=1
  sysctl -w net.ipv4.ip_local_port_range="4000 65000"
  sysctl -w net.ipv4.tcp_max_syn_backlog=65535
  sysctl -w net.core.netdev_max_backlog=65535
  sysctl -w net.core.somaxconn=65535
  sysctl -w vm.swappiness=1
  sysctl -w vm.dirty_background_ratio=5
  sysctl -w vm.dirty_ratio=15

  if ! grep -q pam_limits.so /etc/pam.d/common-session; then
    echo "session required pam_limits.so" >> /etc/pam.d/common-session
  fi

  ulimit -n 200000

  # Mark setup as complete
  mkdir /opt/mysql
  touch "${MYSQL_DONE_FILE}"
  echo "$(date) Setup marker file created at ${MYSQL_DONE_FILE}."
fi

# Wait for the MySQL server to come up
sleep 420

echo "[INFO] Starting automated sysbench benchmark with custom parameters"

# === Retrieve dynamic values from metadata ===
MYSQL_HOST=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/target-server-host)

THREADS=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/thread-count)

MYSQL_MACHINE_TYPE=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/target-machine-type)

case "$MYSQL_HOST" in
  mysql-server-0)
    OPTIMIZATION="none"  # raw server
    ;;
  mysql-server-1)
    OPTIMIZATION="innodbredolog-120"  # optimized server
    ;;
  *)
    OPTIMIZATION="unknown"
    ;;
esac

echo "[INFO] Optimization strategy set to: $OPTIMIZATION for target $MYSQL_HOST"
 
GCS_BUCKET="benchmark-results-hl2-gogl-wopt-t1iylu"
GCS_SUBDIR="mysql/gce"
BENCH_LOG="/opt/${OPTIMIZATION}-${MYSQL_MACHINE_TYPE}-sysbench-results-${THREADS}.txt"
BENCH_DB="test"
BENCH_USER="bench_user"
BENCH_PASS="Bench123_StrongPass"
TABLES=8
TABLE_SIZE=50000000
DURATION=300
RUNS=3

mkdir -p /opt
echo "Sysbench Benchmark Results - $(date)" > "$BENCH_LOG"

echo "Benchmark target MySQL server: $MYSQL_HOST" >> "$BENCH_LOG"
echo "Benchmark thread count: $THREADS" >> "$BENCH_LOG"
echo "Benchmark target MySQL server machine type: $MYSQL_MACHINE_TYPE" >> "$BENCH_LOG"
echo "Optimization attempt: $OPTIMIZATION" >> "$BENCH_LOG"
echo "" >> "$BENCH_LOG"

# === Prepare phase ===
echo "[INFO] Preparing database for load test" >> "$BENCH_LOG"
sysbench oltp_read_write \
  --table-size=$TABLE_SIZE \
  --tables=$TABLES \
  --db-driver=mysql \
  --mysql-host=$MYSQL_HOST \
  --mysql-db=$BENCH_DB \
  --mysql-user=$BENCH_USER \
  --mysql-password=$BENCH_PASS \
  --mysql-ssl=REQUIRED \
  --mysql-ignore-errors=all \
  --threads=8 \
  --db-ps-mode=disable \
  --skip_trx=on \
  prepare >> "$BENCH_LOG" 2>&1

# === Load test phase ===
for i in $(seq 1 $RUNS); do
  echo "" >> "$BENCH_LOG"
  echo "===== RUN $i with THREADS = $THREADS at $(date) =====" >> "$BENCH_LOG"

  sysbench oltp_read_write \
    --table-size=$TABLE_SIZE \
    --tables=$TABLES \
    --db-driver=mysql \
    --mysql-host=$MYSQL_HOST \
    --mysql-db=$BENCH_DB \
    --mysql-user=$BENCH_USER \
    --mysql-password=$BENCH_PASS \
    --mysql-ssl=REQUIRED \
    --mysql-ignore-errors=all \
    --threads=$THREADS \
    --time=$DURATION \
    --db-ps-mode=disable \
    --skip_trx=on \
    --report-interval=1 \
    run >> "$BENCH_LOG" 2>&1

  echo "[INFO] Run $i finished at $(date)" >> "$BENCH_LOG"
done

# === Cleanup phase ===
echo "" >> "$BENCH_LOG"
echo "[INFO] Cleaning up test tables from database" >> "$BENCH_LOG"
sysbench oltp_read_write \
  --table-size=$TABLE_SIZE \
  --tables=$TABLES \
  --mysql-host=$MYSQL_HOST \
  --mysql-db=$BENCH_DB \
  --mysql-user=$BENCH_USER \
  --mysql-password=$BENCH_PASS \
  --mysql-ssl=REQUIRED \
  --threads=8 \
  cleanup >> "$BENCH_LOG" 2>&1

echo "[INFO] All sysbench runs completed at $(date). Results saved to $BENCH_LOG"

echo "[INFO] Uploading results to GCS: gs://${GCS_BUCKET}/${GCS_SUBDIR}"

gcloud storage cp "$BENCH_LOG" "gs://${GCS_BUCKET}/${GCS_SUBDIR}/$(date +'%Y_%m_%d_%H_%M_%S')_$(basename "$BENCH_LOG")"

echo "$(date) Metadata script execution completed."


