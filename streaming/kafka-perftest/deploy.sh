#!/bin/bash

source common.sh

ZONES='zones=["us-central1-a", "us-central1-b", "us-central1-c"]'

PS3='Please enter your choice: '
options=(
         "c4a-highmem-2" \
         "c4a-standard-4" \
         "c4-highmem-2" \
         "c4-highmem-2-single-zone" \
         "c4-standard-4" \
         "c4d-highmem-2-single-zone" \
         "c3d-standard-4" \
         "Quit"
        )
select opt in "${options[@]}"
do
    case $opt in
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
    --var kafka_node_pool_instance_type=$MACHINE_TYPE
# Get cluster credentials
# gcloud container clusters get-credentials ${KUBERNETES_CLUSTER_PREFIX}-cluster --region ${REGION}

gcloud container clusters get-credentials ${KUBERNETES_CLUSTER_PREFIX}-cluster --region ${REGION}  


NAMESPACE="kafka"
TEST_RESULTS=testresults.txt
kubectl create ns $NAMESPACE

#kubectl apply -f kafka-kraft/hd-balanced.yaml
kubectl apply -f kafka-kraft/hd-balanced-xfs.yaml


kubectl apply -f kafka-kraft/perftest.yaml -n $NAMESPACE

echo "Kafka performance test" >$TEST_RESULTS
echo "Machine type: $MACHINE_TYPE" >>$TEST_RESULTS
echo "Test date and time: $(date '+%Y-%m-%d %H:%M:%S')" >>$TEST_RESULTS

for run in {1..3}
do
kubectl apply -f $MANIFEST_FILE -n $NAMESPACE
kubectl wait --for=condition=Ready pod/kafka-0 -n $NAMESPACE --timeout=1200s
kubectl wait --for=condition=Ready pod/kafka-1 -n $NAMESPACE --timeout=1200s
kubectl wait --for=condition=Ready pod/kafka-2 -n $NAMESPACE --timeout=1200s

sleep 2m
kubectl cp test.sh kafka-perftest:/opt/kafka -n $NAMESPACE
kubectl exec -it kafka-perftest -n $NAMESPACE -- chmod +x /opt/kafka/test.sh 
kubectl exec -it kafka-perftest -n $NAMESPACE -- bash -c "/opt/kafka/test.sh kafka-svc.kafka.svc.cluster.local:9092" |tee -a $TEST_RESULTS

kubectl delete -f $MANIFEST_FILE -n $NAMESPACE
sleep 30
done

gsutil cp $TEST_RESULTS  gs://benchmark-results-hl2-gogl-wopt-t1iylu/kafka/gke/$TEST_FILE_EXT-ubxfs-$(date +"%Y_%m_%d_%I_%M_%p").txt
rm $TEST_RESULTS

