#!/bin/bash

export PROJECT_ID="hl2-gogl-wopt-t1iylu"
export REGION="us-central1"
export NUMRECORDS=50000000
export GCSBUCKET="benchmark-results-hl2-gogl-wopt-t1iylu"

KUBERNETES_CLUSTER_PREFIX=kafka-v2
CLUSTER_DATAPATH_PROVIDER=LEGACY_DATAPATH  
ZONES='zones=["us-central1-a", "us-central1-b", "us-central1-c"]'
DEPLOY_ZONES="us-central1-a us-central1-b us-central1-c"

KAFKA_BOOT_DISK_TYPE="hyperdisk-balanced"
NODE_NUMBER=3


# Test config
PERF_MACHINE_TYPE=c4-standard-8
PERFTEST_MANIFEST_FILE="kafka-kraft/perftest.yaml"
PERFTEST_REPLICAS=1
TOPIC_REPLICATION_FACTOR=3
TEST_TYPE="1Ldr3Br"

# Baseline config
NAMESPACE="kafka"
BASE_OS_TYPE=cos
BASE_PD_FILE_SYSTEM=ext4
BASE_NODE_IMAGE_TYPE="COS_CONTAINERD"
BASE_TEST_RESULTS=base-testresults.txt
BASE_TEST_RESULTS_CSV=base-testresults.csv

# Tested config
TUNED_NAMESPACE="kafka-tuned"
TUNED_OS_TYPE=cos
TUNED_PD_FILE_SYSTEM=xfs
TUNED_NODE_IMAGE_TYPE="COS_CONTAINERD"
TUNED_HD_THROUGHPUT="400Mi"
TUNED_HD_IOPS="3000"
TUNED_TEST_RESULTS=tuned-testresults.txt
TUNED_TEST_RESULTS_CSV=tuned-testresults.csv

PS3='Please enter your choice: '
options=(
         "c4-highmem-2-multi-zone" \
         "c4a-highmem-2-multi-zone" \
         "c3d-standard-4-multi-zone" \
         "Quit"
        )
select opt in "${options[@]}"
do
    case $opt in
         "c4-highmem-2-multi-zone")
            echo "you chose ${opt}"
            MACHINE_TYPE="c4-highmem-2"
            TEST_FILE_EXT=$opt
            BASE_MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem-singlebroker-zonal-base.yaml"
            TUNED_MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem-singlebroker-zonal-tuned.yaml"
            PERFTEST_MANIFEST_FILE="kafka-kraft/perftest-zonal.yaml"
            NODE_NUMBER=1
            TOPIC_REPLICATION_FACTOR=1
            TEST_TYPE="1Ldr1Br3z"
            break
            ;;
        "c4a-highmem-2-multi-zone")
            echo "you chose ${opt}"
            MACHINE_TYPE="c4a-highmem-2"
            TEST_FILE_EXT=$opt
            BASE_MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem-arm-singlebroker-zonal-base.yaml"
            TUNED_MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem-arm-singlebroker-zonal-tuned.yaml"
            PERFTEST_MANIFEST_FILE="kafka-kraft/perftest-zonal.yaml"
            NODE_NUMBER=1
            TOPIC_REPLICATION_FACTOR=1
            TEST_TYPE="1Ldr1Br3z"
            break
            ;;
        "c3d-standard-4-multi-zone")
            echo "you chose ${opt}"
            MACHINE_TYPE="c3d-standard-4"
            TEST_FILE_EXT=$opt
            BASE_MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem-singlebroker-zonal-base.yaml"
            TUNED_MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem-singlebroker-zonal-tuned.yaml"
            PERFTEST_MANIFEST_FILE="kafka-kraft/perftest-zonal.yaml"
            NODE_NUMBER=1
            TOPIC_REPLICATION_FACTOR=1
            TEST_TYPE="1Ldr1Br3z"
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
terraform -chdir=terraform/gke-standard-v2 init
terraform -chdir=terraform/gke-standard-v2 apply \
    --var project_id=$PROJECT_ID \
    --var cluster_prefix=${KUBERNETES_CLUSTER_PREFIX} \
    --var kafka_node_pool_instance_type=$MACHINE_TYPE \
    --var perftest_node_pool_instance_type=$PERF_MACHINE_TYPE \
    --var kafka_boot_disk_type=$KAFKA_BOOT_DISK_TYPE \
    --var region=$REGION \
    --var kafka_max_count=$NODE_NUMBER \
    --var kafka_image_type=$BASE_NODE_IMAGE_TYPE \
    --var tuned_kafka_image_type=$TUNED_NODE_IMAGE_TYPE \
    --var datapath_provider=$CLUSTER_DATAPATH_PROVIDER

# Get cluster credentials
# gcloud container clusters get-credentials ${KUBERNETES_CLUSTER_PREFIX}-cluster --region ${REGION}

gcloud container clusters get-credentials ${KUBERNETES_CLUSTER_PREFIX}-cluster --region ${REGION}

kubectl create ns $NAMESPACE
kubectl create ns $TUNED_NAMESPACE

kubectl apply -f kafka-kraft/hd-balanced-base.yaml

cat kafka-kraft/hd-balanced-tuned.yaml |\
    sed "s/{{FSTYPE}}/$TUNED_PD_FILE_SYSTEM/g" |\
    sed "s/{{THROUGHTPUT}}/$TUNED_HD_THROUGHPUT/g" |\
    sed "s/{{IOPS}}/$TUNED_HD_IOPS/g" |\
    kubectl apply -n $NAMESPACE -f -


cat << EOF > $BASE_TEST_RESULTS
Base Kafka performance test
Machine type, $MACHINE_TYPE
PD filesystem, $BASE_PD_FILE_SYSTEM
Node image type, $BASE_NODE_IMAGE_TYPE
Test date and time, $(date '+%Y-%m-%d %H:%M:%S')
provisioned-throughput-on-create, default
provisioned-iops-on-create, default

EOF

cat << EOF > $TUNED_TEST_RESULTS
Tuned Kafka performance test
Machine type, $MACHINE_TYPE
PD filesystem, $TUNED_PD_FILE_SYSTEM
Node image type, $TUNED_NODE_IMAGE_TYPE
Test date and time, $(date '+%Y-%m-%d %H:%M:%S')
Tuning steps:
provisioned-throughput-on-create, $TUNED_HD_THROUGHPUT
provisioned-iops-on-create, $TUNED_HD_IOPS

EOF

cp $BASE_TEST_RESULTS $BASE_TEST_RESULTS_CSV
cp $TUNED_TEST_RESULTS $TUNED_TEST_RESULTS_CSV

case $TEST_TYPE in
      "1Ldr1Br3z")
        for zone in $DEPLOY_ZONES
        do          
            
            echo "Runing test in zone $zone"
            cat $PERFTEST_MANIFEST_FILE | sed "s/{{ZONE}}/$zone/g" | kubectl apply -n $NAMESPACE -f -
            cat $BASE_MANIFEST_FILE | sed "s/{{ZONE}}/$zone/g" | kubectl apply -n $NAMESPACE -f -
            cat $TUNED_MANIFEST_FILE | sed "s/{{ZONE}}/$zone/g" | kubectl apply -n $TUNED_NAMESPACE -f -


            pod_number=$(kubectl get statefulset kafka -n kafka -o=jsonpath='{.spec.replicas}')
            for (( pod=0; pod<pod_number; pod++ ))
            do
                kubectl wait --for=condition=Ready pod/kafka-$pod -n $NAMESPACE --timeout=1200s
                kubectl wait --for=condition=Ready pod/kafka-$pod -n $TUNED_NAMESPACE --timeout=1200s
            done

            sleep 30

            kubectl cp test.sh kafka-perftest:/opt/kafka -n $NAMESPACE
            kubectl exec -it kafka-perftest -n $NAMESPACE -- chmod +x /opt/kafka/test.sh 
            kubectl exec -it kafka-perftest -n $NAMESPACE -- bash -c "/opt/kafka/test.sh kafka-svc.kafka.svc.cluster.local:9092 test-topic-0 $NUMRECORDS $TOPIC_REPLICATION_FACTOR" |tee -a $zone-$BASE_TEST_RESULTS
            kubectl exec -it kafka-perftest -n $NAMESPACE -- bash -c "/opt/kafka/test.sh kafka-svc.kafka-tuned.svc.cluster.local:9092 test-topic-0 $NUMRECORDS $TOPIC_REPLICATION_FACTOR" |tee -a $zone-$TUNED_TEST_RESULTS
            
            echo >>$BASE_TEST_RESULTS_CSV
            echo "Zone, $zone" >>$BASE_TEST_RESULTS_CSV
            echo >>$BASE_TEST_RESULTS_CSV

            echo >>$TUNED_TEST_RESULTS
            echo "Zone: $zone" >>$TUNED_TEST_RESULTS
            echo >>$TUNED_TEST_RESULTS

            ./result_parser.sh $zone-$BASE_TEST_RESULTS >>$BASE_TEST_RESULTS_CSV
            cat $zone-$BASE_TEST_RESULTS >>$BASE_TEST_RESULTS
            rm $zone-$BASE_TEST_RESULTS

            ./result_parser.sh $zone-$TUNED_TEST_RESULTS >>$TUNED_TEST_RESULTS_CSV
            cat $zone-$TUNED_TEST_RESULTS >>$TUNED_TEST_RESULTS
            rm $zone-$TUNED_TEST_RESULTS

            cat $PERFTEST_MANIFEST_FILE | sed "s/{{ZONE}}/$zone/g" | kubectl delete -n $NAMESPACE -f -
            cat $BASE_MANIFEST_FILE | sed "s/{{ZONE}}/$zone/g" | kubectl delete -n $NAMESPACE -f -
            cat $TUNED_MANIFEST_FILE | sed "s/{{ZONE}}/$zone/g" | kubectl delete -n $TUNED_NAMESPACE -f -

            kubectl wait --for=delete statefulset/kafka -n $NAMESPACE
            kubectl wait --for=delete statefulset/kafka-tuned -n $NAMESPACE
            kubectl wait --for=delete pod/kafka-perftest -n $TUNED_NAMESPACE
        done

        kubectl delete -f kafka-kraft/hd-balanced-base.yaml
        cat kafka-kraft/hd-balanced-tuned.yaml |\
            sed "s/{{FSTYPE}}/$TUNED_PD_FILE_SYSTEM/g" |\
            sed "s/{{THROUGHTPUT}}/$TUNED_HD_THROUGHPUT/g" |\
            sed "s/{{IOPS}}/$TUNED_HD_IOPS/g" |\
            kubectl delete -f -

        COMBINED_TXT="combined.txt"
        COMBINED_CSV="combined.csv"

        cp $BASE_TEST_RESULTS $COMBINED_TXT
        cp $BASE_TEST_RESULTS_CSV $COMBINED_CSV
        echo "##### END OF BASELINE TEST #####">>$COMBINED_TXT
        echo >>$COMBINED_TXT

        echo "##### END OF BASELINE TEST #####">>$COMBINED_CSV
        echo >>$COMBINED_CSV

        cat $TUNED_TEST_RESULTS >>$COMBINED_TXT
        cat $TUNED_TEST_RESULTS_CSV >>$COMBINED_CSV 
        gsutil cp $COMBINED_TXT  gs://$GCSBUCKET/kafka/gke/$TEST_FILE_EXT-v2-$(date +"%Y_%m_%d_%I_%M_%p").txt
        gsutil cp $COMBINED_CSV  gs://$GCSBUCKET/kafka/gke/csv/$TEST_FILE_EXT-v2-$(date +"%Y_%m_%d_%I_%M_%p").csv
        ;;
    esac



