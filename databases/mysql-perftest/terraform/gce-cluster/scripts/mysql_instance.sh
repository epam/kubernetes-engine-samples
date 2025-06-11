#!/bin/bash
set -e

INSTANCE_INDEX=$(curl -s -H "Metadata-Flavor: Google" \
http://metadata.google.internal/computeMetadata/v1/instance/attributes/instance-index)
 
LOG_FILE="/var/log/mysql-setup.log"
MYSQL_DONE_FILE="/opt/mysql/setup-done"
MYSQL_DISK_ID="google-mysql-server-${INSTANCE_INDEX}-data-disk"
# MYSQL_ROOT="/mnt/mysql-data"
# MYSQL_DATADIR="${MYSQL_ROOT}/mysql"

MYSQL_MOUNT="/var/lib/mysql"

exec > >(tee -a "${LOG_FILE}") 2>&1

if [ -f "${MYSQL_DONE_FILE}" ]; then
    echo "$(date) MySQL is already configured. Skipping setup."
else
  echo "$(date) MySQL is not configured. Beginning setup."

  # === Disk Setup ===
  # echo "[INFO] Preparing and mounting disk: /dev/disk/by-id/${MYSQL_DISK_ID}"
  # if ! mount | grep -q "${MYSQL_ROOT}"; then
  #   mkdir -p "${MYSQL_ROOT}"
  #   # Format data disk differently depending on instance index
  #   # if [ "$INSTANCE_INDEX" -eq 0 ]; then
  #   #   echo "[INFO] Formatting disk as XFS (instance-index=$INSTANCE_INDEX)"
  #   #   mkfs.xfs -f /dev/disk/by-id/${MYSQL_DISK_ID} || true
  #   #   FS_TYPE="xfs"
  #   # else
  #   #   echo "[INFO] Formatting disk as EXT2 (instance-index=$INSTANCE_INDEX)"
  #   #   mkfs.ext2 -F /dev/disk/by-id/${MYSQL_DISK_ID} || true
  #   #   FS_TYPE="ext2"
  #   # fi
  #   echo "[INFO] Formatting disk as XFS (instance-index=$INSTANCE_INDEX)"
  #   mkfs.xfs -f /dev/disk/by-id/${MYSQL_DISK_ID} || true
  #   FS_TYPE="xfs"
  #   # Mount optimized storage depending on instance index
  #   if [ "$INSTANCE_INDEX" -eq 1 ]; then
  #     mount -t "$FS_TYPE" -o logbsize=256k,logbufs=8,inode64,defaults \
  #           /dev/disk/by-id/${MYSQL_DISK_ID} "${MYSQL_ROOT}"
  #     echo "/dev/disk/by-id/${MYSQL_DISK_ID} ${MYSQL_ROOT} ${FS_TYPE} defaults,logbsize=256k,logbufs=8,inode64,nofail 0 2" \
  #         >> /etc/fstab

  #     # Optimizing scheduler options
  #     BLK="/sys/block/$(basename "$(readlink -f "/dev/disk/by-id/${MYSQL_DISK_ID}")")"
  #     echo mq-deadline > "${BLK}/queue/scheduler" 2>/dev/null || true
  #     echo 1023        > "${BLK}/queue/nr_requests" 2>/dev/null || true
  #   else
  #     mount -t "$FS_TYPE" -o defaults /dev/disk/by-id/${MYSQL_DISK_ID} "${MYSQL_ROOT}"
  #     echo "/dev/disk/by-id/${MYSQL_DISK_ID} ${MYSQL_ROOT} ${FS_TYPE} defaults,nofail 0 2" >> /etc/fstab
  #   fi
  # else
  #   echo "[INFO] Disk already mounted on ${MYSQL_ROOT}, skipping format."
  # fi

  if [ "$INSTANCE_INDEX" -eq 1 ]; then
    ########################################################################
    #  server-1  →  build a 10-disk RAID-0 stripe and mount it on /mnt/mysql-data
    ########################################################################

    apt update -qq
    DEBIAN_FRONTEND=noninteractive apt install -y mdadm

    echo "[INFO] server-1: assembling 10-disk RAID0 array for MySQL"

    # discover the ten Terraform-created disks
    mapfile -t RAID_DISKS < <(ls /dev/disk/by-id/google-mysql-server-1-data-disk-* | sort)
    echo "[INFO] RAID members: ${RAID_DISKS[*]}"

    if ! mount | grep -q "${MYSQL_MOUNT}"; then
      mkdir -p "${MYSQL_MOUNT}"

      # create the array once
      if [ ! -e /dev/md0 ]; then
        mdadm --create /dev/md0 --level=stripe --raid-devices=10 "${RAID_DISKS[@]}"
      fi

      # format & mount with larger XFS log stripe
      mkfs.xfs -i size=512 -f /dev/md0
      mount -t xfs -o defaults /dev/md0 "${MYSQL_MOUNT}"
      echo '/dev/md0 '"${MYSQL_MOUNT}"' xfs defaults,nofail 0 2' >> /etc/fstab
    fi

  else
    ########################################################################
    #  every other server  →  single data-disk path (unchanged logic)
    ########################################################################
    echo "[INFO] Preparing single data disk: /dev/disk/by-id/${MYSQL_DISK_ID}"
    if ! mount | grep -q "${MYSQL_MOUNT}"; then
      mkdir -p "${MYSQL_MOUNT}"
      mkfs.xfs -i size=512 -f /dev/disk/by-id/${MYSQL_DISK_ID} || true
      mount -t xfs -o defaults /dev/disk/by-id/${MYSQL_DISK_ID} "${MYSQL_MOUNT}"
      echo "/dev/disk/by-id/${MYSQL_DISK_ID} ${MYSQL_MOUNT} xfs defaults,nofail 0 2" >> /etc/fstab
    fi
  fi
 
  # Waiting for 90 seconds for system setup to release all locks
  sleep 90
  echo "[INFO] Installing MySQL 8.0"
  
  apt update
  DEBIAN_FRONTEND=noninteractive apt install -y wget gnupg lsb-release

  wget https://dev.mysql.com/get/mysql-apt-config_0.8.34-1_all.deb
  DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.34-1_all.deb

  # Comment out line below if MySQL 8.4 is preffered
  sed -i 's/mysql-8.4/mysql-8.0/' /etc/apt/sources.list.d/mysql.list || true

  apt update
  DEBIAN_FRONTEND=noninteractive apt install -y mysql-server

  systemctl stop mysql

  # Ops Agent installation
  echo "[INFO] Installing Cloud Ops Agent"
  curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
  sudo bash add-google-cloud-ops-agent-repo.sh --also-install

  # mkdir -p "${MYSQL_DATADIR}"
  # chown -R mysql:mysql "${MYSQL_DATADIR}"
  # chmod 750 "${MYSQL_DATADIR}"

  #   # === Patch AppArmor ===
  # echo "[INFO] Updating AppArmor rules for MySQL"
  
  # APPARMOR_FILE="/etc/apparmor.d/usr.sbin.mysqld"
  
  # sed -i \
  #   -e 's|/var/lib/mysql/|/mnt/mysql-data/mysql/|g' \
  #   -e 's|/var/lib/mysql/\*\*|/mnt/mysql-data/mysql/**|g' \
  #   "$APPARMOR_FILE"
  
  # # Reload AppArmor profile
  # apparmor_parser -r "$APPARMOR_FILE"

  echo "[INFO] Writing SSL certificates from metadata"

  mkdir -p "${MYSQL_MOUNT}"/ssl
  chmod 700 "${MYSQL_MOUNT}"/ssl

  echo "$(curl -s -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/attributes/ca-pem)" > "${MYSQL_MOUNT}"/ssl/ca.pem
  echo "$(curl -s -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/attributes/server-cert-pem)" > "${MYSQL_MOUNT}"/ssl/server-cert.pem
  echo "$(curl -s -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/attributes/server-key-pem)" > "${MYSQL_MOUNT}"/ssl/server-key.pem

  chown mysql:mysql "${MYSQL_MOUNT}"/ssl/*.pem
  chmod 600 "${MYSQL_MOUNT}"/ssl/server-key.pem
  chmod 644 "${MYSQL_MOUNT}"/ssl/server-cert.pem "${MYSQL_MOUNT}"/ssl/ca.pem


  # mysqld --initialize-insecure --user=mysql

  # === Configure MySQL ===
  echo "[INFO] Configuring MySQL"

  cat <<EOF > /etc/mysql/mysql.conf.d/mysqld.cnf
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
  max_connections = 3000
  max_prepared_stmt_count = 1048576
EOF

  # Possible Kernel optimization section
  if [ "$INSTANCE_INDEX" -eq 1 ]; then
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
  fi

#   mkdir -p /etc/systemd/system/mysql.service.d

#   cat <<EOF > /etc/systemd/system/mysql.service.d/override.conf
#   [Service]
#   LimitNOFILE=200000
# EOF

#   systemctl daemon-reexec
#   systemctl daemon-reload
  systemctl start mysql
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