#!/bin/bash

source common.sh
REGION="us-central1"
ZONES='zones=["us-central1-a", "us-central1-b", "us-central1-c"]'
PERF_MACHINE_TYPE=c4-standard-8
KAFKA_BOOT_DISK_TYPE="hyperdisk-balanced"

PS3='Please enter your choice: '
options=(
         "c4-standard-48-2cpu" \
         "c4a-highmem-2" \
         "c4a-standard-4" \
         "c4-highmem-2" \
         "c4-highmem-2-eu" \
         "c4-highmem-2-tuned" \
         "c4-highmem-2-single-zone" \
         "c4-standard-4" \
         "c4-standard-4-2cpu" \
         "c4-standard-8-2cpu" \
         "c4d-highmem-2-single-zone" \
         "c3d-standard-4" \
         "n2-highmem-2" \
         "c4-highmem-2-network-test"\
         "Quit"
        )
select opt in "${options[@]}"
do
    case $opt in
        "c4-standard-48-2cpu")
            echo "you chose ${opt}"
            MACHINE_TYPE="c4-standard-48"
            PERF_MACHINE_TYPE="c4-standard-48"
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem.yaml"
            break
            ;;
        "c4a-highmem-2")
            echo "you chose ${opt}"
            MACHINE_TYPE=$opt
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem-arm.yaml"
            break
            ;;
        "c4a-standard-4")
            echo "you chose ${opt}"
            MACHINE_TYPE=$opt
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-4cpu-arm.yaml"
            break
            ;;
        "c4-highmem-2")
            echo "you chose ${opt}"
            MACHINE_TYPE=$opt
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem.yaml"
            break
            ;;
        "c4-highmem-2-eu")
            echo "you chose ${opt}"
            MACHINE_TYPE="c4-highmem-2"
            TEST_FILE_EXT=$opt
            REGION="europe-west4"
            MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem.yaml"
            ZONES='zones=["europe-west4-a", "europe-west4-b", "europe-west4-c"]'
            break
            ;;
        "c4-highmem-2-tuned")
            echo "you chose ${opt}"
            MACHINE_TYPE="c4-highmem-2"
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem-tuned.yaml"
            break
            ;;
        "c4-highmem-2-single-zone")
            echo "you chose ${opt}"
            MACHINE_TYPE="c4-highmem-2"
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem.yaml"
            ZONES='zones=["us-central1-a"]'
            break
            ;;
        "c4-standard-4")
            echo "you chose ${opt}"
            MACHINE_TYPE=$opt
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-4cpu-x64.yaml"
            break
            ;;
        "c4-standard-4-2cpu")
            echo "you chose ${opt}"
            MACHINE_TYPE="c4-standard-4"
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem.yaml"
            break
            ;;
        "c4-standard-8-2cpu")
            echo "you chose ${opt}"
            MACHINE_TYPE="c4-standard-8"
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem.yaml"
            break
            ;;
        "c4d-highmem-2-single-zone")
            echo "you chose choice $REPLY which is $opt"
            MACHINE_TYPE="c4d-highmem-2"
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem.yaml"
            ZONES='zones=["us-central1-a"]'
            break
            ;;
        "c3d-standard-4")
            echo "you chose choice $REPLY which is $opt"
            MACHINE_TYPE=$opt
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-4cpu-x64.yaml"
            break
            ;;
        "n2-highmem-2")
            echo "you chose choice $REPLY which is $opt"
            MACHINE_TYPE=$opt
            TEST_FILE_EXT=$opt
            KAFKA_BOOT_DISK_TYPE="pd-ssd"
            MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem-no-hd.yaml"
            break
            ;;
        "c4-highmem-2-network-test")
            echo "you chose ${opt}"
            MACHINE_TYPE="c4-highmem-2"
            PERF_MACHINE_TYPE="c4-standard-2"
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem.yaml"
            break
            ;;
        "Quit")
            exit
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

echo $ZONES > terraform/gke-standard/terraform.tfvars

# Create clusters
terraform -chdir=terraform/gke-standard init
terraform -chdir=terraform/gke-standard apply \
    --var project_id=$PROJECT_ID \
    --var cluster_prefix=${KUBERNETES_CLUSTER_PREFIX} \
    --var kafka_node_pool_instance_type=$MACHINE_TYPE \
    --var perftest_node_pool_instance_type=$PERF_MACHINE_TYPE \
    --var kafka_boot_disk_type=$KAFKA_BOOT_DISK_TYPE \
    --var region=$REGION
# Get cluster credentials
# gcloud container clusters get-credentials ${KUBERNETES_CLUSTER_PREFIX}-cluster --region ${REGION}

gcloud container clusters get-credentials ${KUBERNETES_CLUSTER_PREFIX}-cluster --region ${REGION}  


NAMESPACE="kafka"
TEST_RESULTS=testresults.txt
TEST_RESULTS_CSV=testresults.csv
PD_FILE_SYSTEM=xfs
kubectl create ns $NAMESPACE

#kubectl apply -f kafka-kraft/hd-balanced.yaml
kubectl apply -f kafka-kraft/hd-balanced-$PD_FILE_SYSTEM.yaml


kubectl apply -f kafka-kraft/perftest-3.yaml -n $NAMESPACE

cat << EOF > $TEST_RESULTS
Kafka performance test
Machine type, $MACHINE_TYPE
PD filesystem, $PD_FILE_SYSTEM
Test date and time, $(date '+%Y-%m-%d %H:%M:%S')
Tuning steps:
provisioned-throughput-on-create, 400Mi
provisioned-iops-on-create, 6000

EOF

cp $TEST_RESULTS $TEST_RESULTS_CSV

for run in {0..2}
do
kubectl apply -f $MANIFEST_FILE -n $NAMESPACE
kubectl wait --for=condition=Ready pod/kafka-0 -n $NAMESPACE --timeout=1200s
kubectl wait --for=condition=Ready pod/kafka-1 -n $NAMESPACE --timeout=1200s
kubectl wait --for=condition=Ready pod/kafka-2 -n $NAMESPACE --timeout=1200s

sleep 30
kubectl cp test.sh kafka-perftest-$run:/opt/kafka -n $NAMESPACE
kubectl exec -it kafka-perftest-$run -n $NAMESPACE -- chmod +x /opt/kafka/test.sh 

# kubectl delete -f $MANIFEST_FILE -n $NAMESPACE
# sleep 30
done

kubectl exec -it kafka-perftest-0 -n $NAMESPACE -- bash -c "/opt/kafka/test.sh kafka-svc.kafka.svc.cluster.local:9092 test-topic-0 $NUMRECORDS 3" |tee -a "$TEST_RESULTS-0" &
kubectl exec -it kafka-perftest-1 -n $NAMESPACE -- bash -c "/opt/kafka/test.sh kafka-svc.kafka.svc.cluster.local:9092 test-topic-1 $NUMRECORDS 3" |tee -a "$TEST_RESULTS-1" &
kubectl exec -it kafka-perftest-2 -n $NAMESPACE -- bash -c "/opt/kafka/test.sh kafka-svc.kafka.svc.cluster.local:9092 test-topic-2 $NUMRECORDS 3" |tee -a "$TEST_RESULTS-2"

wait

kubectl delete -f $MANIFEST_FILE -n $NAMESPACE
kubectl delete -f kafka-kraft/hd-balanced-$PD_FILE_SYSTEM.yaml

for i = {0..2} 
do
./result_parser.sh $TEST_RESULTS-$i >>$TEST_RESULTS_CSV
done

gsutil cp $TEST_RESULTS  gs://$GCSBUCKET/kafka/gke/$TEST_FILE_EXT-ub$PD_FILE_SYSTEM-$(date +"%Y_%m_%d_%I_%M_%p").txt
gsutil cp $TEST_RESULTS_CSV  gs://$GCSBUCKET/kafka/gke/csv/$TEST_FILE_EXT-ub$PD_FILE_SYSTEM-$(date +"%Y_%m_%d_%I_%M_%p").csv
rm $TEST_RESULTS

