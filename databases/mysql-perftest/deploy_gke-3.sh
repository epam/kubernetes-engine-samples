#!/bin/bash
set -e

export PROJECT_ID="hl2-gogl-wopt-t1iylu"
export REGION="us-central1"
export GCSBUCKET="benchmark-results-hl2-gogl-wopt-t1iylu"
KUBE_TEMP_DIR="${HOME}/.kube/temp-configs"

#Create temp kube-config
mkdir -p "${KUBE_TEMP_DIR}"
TEMP_KUBECONFIG_FILE="${KUBE_TEMP_DIR}/config-3"
cleanup() {
    echo "--> Cleaning up secure kubeconfig file: ${TEMP_KUBECONFIG_FILE}"
    rm -f "${TEMP_KUBECONFIG_FILE}"
}
trap cleanup EXIT
export KUBECONFIG="${TEMP_KUBECONFIG_FILE}"

KUBERNETES_CLUSTER_PREFIX=mysql2
CLUSTER_DATAPATH_PROVIDER=LEGACY_DATAPATH
ZONES='zones=["us-central1-a", "us-central1-a"]'
DEPLOY_ZONES="us-central1-a us-central1-a"

MYSQL_BOOT_DISK_TYPE="hyperdisk-balanced"
SYSBENCH_BOOT_DISK_TYPE="hyperdisk-balanced"
NODE_NUMBER=1


# Sysbench config
SYSBENCH_MACHINE_TYPE=c4d-standard-32
# SYSBENCH_MANIFEST_FILE="mysql/sysbench.yaml"
SYSBENCH_NODES_NUMBER=2
MASTER_IPV4_CIDR_BLOCK="172.16.0.32/28"
TEST_TYPE="1Ldr1Mysql"

# Baseline config
NAMESPACE="mysql"
BASE_OS_TYPE=cos
BASE_PD_FILE_SYSTEM=xfs
BASE_NODE_IMAGE_TYPE="COS_CONTAINERD"
BASE_TEST_RESULTS=base-testresults.txt
BASE_TEST_RESULTS_CSV=base-testresults.csv

# Tuned config
TUNED_NAMESPACE="mysql-tuned"
TUNED_OS_TYPE=cos
TUNED_PD_FILE_SYSTEM=ext4
TUNED_NODE_IMAGE_TYPE="COS_CONTAINERD"
# TUNED_HD_THROUGHPUT="400Mi"
# TUNED_HD_IOPS="3000"
TUNED_TEST_RESULTS=tuned-testresults.txt
TUNED_TEST_RESULTS_CSV=tuned-testresults.csv

PS3='Please enter your choice: '
options=(
         "c4-highmem-16-single-zone" \
         "c4d-highmem-16-single-zone" \
         "c4a-highmem-16-single-zone" \
         "Quit"
        )
select opt in "${options[@]}"
do
    case $opt in
         "c4-highmem-16-single-zone")
            echo "you chose ${opt}"
            MACHINE_TYPE="c4-highmem-16"
            SYSBENCH_MACHINE_TYPE=c4-standard-32
            TEST_FILE_EXT=$opt
            BASE_MANIFEST_FILE="mysql/mysql-single-zonal-base.yaml"
            TUNED_MANIFEST_FILE="mysql/mysql-single-zonal-tuned-swap.yaml"
            BASE_SYSBENCH_MANIFEST_FILE="mysql/generated/sysbench/base/sysbench-single-node-512-base.yaml"
            TUNED_SYSBENCH_MANIFEST_FILE="mysql/generated/sysbench/tuned/sysbench-single-node-512-tuned.yaml"
            KERNEL_TUNE_FILE="mysql/node-all-kernel-set.yaml"
            # NODE_NUMBER=7
            TEST_TYPE="1Ldr1Mysql"
            break
            ;;
        "c4d-highmem-16-single-zone")
            echo "you chose ${opt}"
            MACHINE_TYPE="c4d-highmem-16"
            SYSBENCH_MACHINE_TYPE=c4d-standard-32
            TEST_FILE_EXT=$opt
            BASE_MANIFEST_FILE="mysql/mysql-single-zonal-base.yaml"
            TUNED_MANIFEST_FILE="mysql/mysql-single-zonal-tuned-swap.yaml"
            BASE_SYSBENCH_MANIFEST_FILE="mysql/generated/sysbench/base/sysbench-single-node-512-base.yaml"
            TUNED_SYSBENCH_MANIFEST_FILE="mysql/generated/sysbench/tuned/sysbench-single-node-512-tuned.yaml"
            KERNEL_TUNE_FILE="mysql/node-all-kernel-set.yaml"
            # NODE_NUMBER=7
            TEST_TYPE="1Ldr1Mysql"
            break
            ;;
        "c4a-highmem-16-single-zone")
            echo "you chose ${opt}"
            MACHINE_TYPE="c4a-highmem-16"
            SYSBENCH_MACHINE_TYPE=c4a-standard-32
            SYSBENCH_BOOT_DISK_TYPE="hyperdisk-balanced"
            TEST_FILE_EXT=$opt
            BASE_MANIFEST_FILE="mysql/mysql-single-zonal-base-arm.yaml"
            TUNED_MANIFEST_FILE="mysql/mysql-single-zonal-tuned-arm-swap.yaml"
            BASE_SYSBENCH_MANIFEST_FILE="mysql/generated/sysbench/base/sysbench-single-node-512-base-arm.yaml"
            TUNED_SYSBENCH_MANIFEST_FILE="mysql/generated/sysbench/tuned/sysbench-single-node-512-tuned-arm.yaml"
            KERNEL_TUNE_FILE="mysql/node-all-kernel-set-arm.yaml"
            # NODE_NUMBER=7
            TEST_TYPE="1Ldr1Mysql"
            break
            ;;
         "Quit")
            exit
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

echo $ZONES > terraform/gke-standard-3/terraform.tfvars

# Create clusters
terraform -chdir=terraform/gke-standard-3 init
terraform -chdir=terraform/gke-standard-3 apply \
    --var project_id=$PROJECT_ID \
    --var cluster_prefix=${KUBERNETES_CLUSTER_PREFIX} \
    --var mysql_node_pool_instance_type=$MACHINE_TYPE \
    --var sysbench_node_pool_instance_type=$SYSBENCH_MACHINE_TYPE \
    --var mysql_boot_disk_type=$MYSQL_BOOT_DISK_TYPE \
    --var sysbench_boot_disk_type=$SYSBENCH_BOOT_DISK_TYPE \
    --var region=$REGION \
    --var mysql_max_count=$NODE_NUMBER \
    --var sysbench_max_count=$SYSBENCH_NODES_NUMBER \
    --var mysql_image_type=$BASE_NODE_IMAGE_TYPE \
    --var tuned_mysql_image_type=$TUNED_NODE_IMAGE_TYPE \
    --var datapath_provider=$CLUSTER_DATAPATH_PROVIDER \
    --var master_ipv4_cidr_block=$MASTER_IPV4_CIDR_BLOCK

# Get cluster credentials
gcloud container clusters get-credentials ${KUBERNETES_CLUSTER_PREFIX}-cluster --region ${REGION}

kubectl create ns $NAMESPACE || true
kubectl create ns $TUNED_NAMESPACE || true

kubectl apply -f mysql/hd-balanced-base.yaml || true
# kubectl apply -f mysql/hd-balanced-tuned.yaml || true

# cat mysql/hd-balanced-tuned.yaml |\
#     sed "s/{{FSTYPE}}/$TUNED_PD_FILE_SYSTEM/g" |\
#     sed "s/{{THROUGHTPUT}}/$TUNED_HD_THROUGHPUT/g" |\
#     sed "s/{{IOPS}}/$TUNED_HD_IOPS/g" |\
#     kubectl apply -n $NAMESPACE -f -

kubectl create secret generic mysql-ssl-certs \
  --from-file=mysql/ssl/ca.pem \
  --from-file=mysql/ssl/server-cert.pem \
  --from-file=mysql/ssl/server-key.pem \
  --from-file=mysql/ssl/client-cert.pem \
  --from-file=mysql/ssl/client-key.pem \
  -n $NAMESPACE || true

kubectl create secret generic mysql-ssl-certs \
  --from-file=mysql/ssl/ca.pem \
  --from-file=mysql/ssl/server-cert.pem \
  --from-file=mysql/ssl/server-key.pem \
  --from-file=mysql/ssl/client-cert.pem \
  --from-file=mysql/ssl/client-key.pem \
  -n $TUNED_NAMESPACE || true

# cat << EOF > $BASE_TEST_RESULTS
# Base Kafka performance test
# Machine type, $MACHINE_TYPE
# PD filesystem, $BASE_PD_FILE_SYSTEM
# Node image type, $BASE_NODE_IMAGE_TYPE
# Test date and time, $(date '+%Y-%m-%d %H:%M:%S')
# provisioned-throughput-on-create, default
# provisioned-iops-on-create, default

# EOF

# cat << EOF > $TUNED_TEST_RESULTS
# Tuned Kafka performance test
# Machine type, $MACHINE_TYPE
# PD filesystem, $TUNED_PD_FILE_SYSTEM
# Node image type, $TUNED_NODE_IMAGE_TYPE
# Test date and time, $(date '+%Y-%m-%d %H:%M:%S')
# Tuning steps:
# provisioned-throughput-on-create, $TUNED_HD_THROUGHPUT
# provisioned-iops-on-create, $TUNED_HD_IOPS

# EOF

# cp $BASE_TEST_RESULTS $BASE_TEST_RESULTS_CSV
# cp $TUNED_TEST_RESULTS $TUNED_TEST_RESULTS_CSV
kubectl apply -f $KERNEL_TUNE_FILE || true
kubectl rollout status "daemonset/node-kernel-defaults-setter" -n kube-system

# kubectl apply -f mysql/node-swappiness-setter.yaml || true
# kubectl rollout status "daemonset/node-swappiness-setter" -n kube-system

case $TEST_TYPE in
      "1Ldr1Mysql")
        for zone in $DEPLOY_ZONES
        do

            echo "Runing test in zone $zone"

            #Create Statefulsets
            cat $BASE_MANIFEST_FILE | sed "s/{{ZONE}}/$zone/g" | kubectl apply -n $NAMESPACE -f -
            cat $TUNED_MANIFEST_FILE | sed "s/{{ZONE}}/$zone/g" | kubectl apply -n $TUNED_NAMESPACE -f -
            # cat $SYSBENCH_MANIFEST_FILE | sed "s/{{ZONE}}/$zone/g" | kubectl apply -n $NAMESPACE -f -

            # kubectl apply -f mysql/generated/

            # pod_number=$(kubectl get statefulset mysql -n mysql -o=jsonpath='{.spec.replicas}')
            # for (( pod=0; pod<pod_number; pod++ ))
            # do
            #     kubectl wait --for=condition=Ready pod/mysql-$pod -n $NAMESPACE --timeout=1200s
            #     # kubectl wait --for=condition=Ready pod/mysql-$pod -n $TUNED_NAMESPACE --timeout=1200s
            # done

            # sleep 30

            # kubectl cp test.sh mysql-sysbench:/opt/mysql -n $NAMESPACE
            # kubectl exec -it mysql-sysbench -n $NAMESPACE -- chmod +x /opt/mysql/test.sh 
            # kubectl exec -it mysql-sysbench -n $NAMESPACE -- bash -c "/opt/mysql/test.sh mysql-svc.mysql.svc.cluster.local:9092 test-topic-0 $NUMRECORDS $TOPIC_REPLICATION_FACTOR" |tee -a $zone-$BASE_TEST_RESULTS
            # kubectl exec -it mysql-sysbench -n $NAMESPACE -- bash -c "/opt/mysql/test.sh mysql-svc.mysql-tuned.svc.cluster.local:9092 test-topic-0 $NUMRECORDS $TOPIC_REPLICATION_FACTOR" |tee -a $zone-$TUNED_TEST_RESULTS

            # echo >>$BASE_TEST_RESULTS_CSV
            # echo "Zone, $zone" >>$BASE_TEST_RESULTS_CSV
            # echo >>$BASE_TEST_RESULTS_CSV

            # echo >>$TUNED_TEST_RESULTS
            # echo "Zone: $zone" >>$TUNED_TEST_RESULTS
            # echo >>$TUNED_TEST_RESULTS

            # ./result_parser.sh $zone-$BASE_TEST_RESULTS >>$BASE_TEST_RESULTS_CSV
            # cat $zone-$BASE_TEST_RESULTS >>$BASE_TEST_RESULTS
            # rm $zone-$BASE_TEST_RESULTS

            # ./result_parser.sh $zone-$TUNED_TEST_RESULTS >>$TUNED_TEST_RESULTS_CSV
            # cat $zone-$TUNED_TEST_RESULTS >>$TUNED_TEST_RESULTS
            # rm $zone-$TUNED_TEST_RESULTS

            # cat $SYSBENCH_MANIFEST_FILE | sed "s/{{ZONE}}/$zone/g" | kubectl delete -n $NAMESPACE -f -
            # cat $BASE_MANIFEST_FILE | sed "s/{{ZONE}}/$zone/g" | kubectl delete -n $NAMESPACE -f -
            # cat $TUNED_MANIFEST_FILE | sed "s/{{ZONE}}/$zone/g" | kubectl delete -n $TUNED_NAMESPACE -f -

            # kubectl wait --for=delete statefulset/mysql -n $NAMESPACE
            # kubectl wait --for=delete statefulset/mysql-tuned -n $NAMESPACE
            # kubectl wait --for=delete pod/mysql-sysbench -n $TUNED_NAMESPACE
        done
        sleep 160
        cat $BASE_SYSBENCH_MANIFEST_FILE | sed "s/{{ZONE}}/$zone/g" | kubectl apply -n $NAMESPACE -f -
        cat $TUNED_SYSBENCH_MANIFEST_FILE | sed "s/{{ZONE}}/$zone/g" | kubectl apply -n $TUNED_NAMESPACE -f -
        # kubectl apply -f mysql/generated/sysbench/base/sysbench-single-node-512-base.yaml -n $NAMESPACE
        # kubectl apply -f mysql/generated/sysbench/tuned/sysbench-single-node-512-tuned.yaml -n $TUNED_NAMESPACE
        # kubectl apply -f mysql/generated/sysbench/tuned/ -n $TUNED_NAMESPACE
        # kubectl delete -f mysql/hd-balanced-base.yaml
        # cat mysql/hd-balanced-tuned.yaml |\
        #     sed "s/{{FSTYPE}}/$TUNED_PD_FILE_SYSTEM/g" |\
        #     sed "s/{{THROUGHTPUT}}/$TUNED_HD_THROUGHPUT/g" |\
        #     sed "s/{{IOPS}}/$TUNED_HD_IOPS/g" |\
        #     kubectl delete -f -

        # COMBINED_TXT="combined.txt"
        # COMBINED_CSV="combined.csv"

        # cp $BASE_TEST_RESULTS $COMBINED_TXT
        # cp $BASE_TEST_RESULTS_CSV $COMBINED_CSV
        # echo "##### END OF BASELINE TEST #####">>$COMBINED_TXT
        # echo >>$COMBINED_TXT

        # echo "##### END OF BASELINE TEST #####">>$COMBINED_CSV
        # echo >>$COMBINED_CSV

        # cat $TUNED_TEST_RESULTS >>$COMBINED_TXT
        # cat $TUNED_TEST_RESULTS_CSV >>$COMBINED_CSV 
        # gsutil cp $COMBINED_TXT  gs://$GCSBUCKET/mysql/gke/$TEST_FILE_EXT-$(date +"%Y_%m_%d_%I_%M_%p").txt
        # gsutil cp $COMBINED_CSV  gs://$GCSBUCKET/mysql/gke/csv/$TEST_FILE_EXT-$(date +"%Y_%m_%d_%I_%M_%p").csv
        ;;
    esac



