#!/bin/bash

source common.sh

ZONES='zones=["us-central1-a", "us-central1-b", "us-central1-c"]'
DEPLOY_ZONES="us-central1-a us-central1-b us-central1-c"
PERF_MACHINE_TYPE=c4-standard-8
KAFKA_BOOT_DISK_TYPE="hyperdisk-balanced"
NODE_NUMBER=3
NODE_IMAGE_TYPE="COS_CONTAINERD"
PERFTEST_MANIFEST_FILE="kafka-kraft/perftest.yaml"
PERFTEST_REPLICAS=1
TOPIC_REPLICATION_FACTOR=3
TEST_TYPE="1Ldr3Br"
OS_TYPE=cos
PS3='Please enter your choice: '
options=(
         "c4-standard-48" \
         "c4a-highmem-2" \
         "c4a-standard-4" \
         "c4a-highmem-2-single-zone" \
         "c4a-highmem-2-single-node" \
         "c4-highmem-2" \
         "c4-highmem-2-tuned" \
         "c4-highmem-2-single-zone" \
         "c4-highmem-2-single-node" \
         "c4-highmem-2-multi-zone" \
         "c4a-highmem-2-multi-zone" \
         "c3d-standard-4-multi-zone" \
         "c4-standard-4" \
         "c4d-highmem-2-single-zone" \
         "c4d-highmem-2-single-node" \
         "c3d-standard-4" \
         "c3d-standard-4-single-node" \
         "c3d-standard-4-single-node-3LG" \
         "n2-highmem-2" \
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
        "c4a-highmem-2-single-zone")
            echo "you chose choice $REPLY which is $opt"
            MACHINE_TYPE="c4a-highmem-2"
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem-arm.yaml"
            ZONES='zones=["us-central1-a"]'
            break
            ;;
        "c4a-highmem-2-single-node")
            echo "you chose choice $REPLY which is $opt"
            MACHINE_TYPE="c4a-highmem-2"
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-single-2cpu-himem-arm.yaml"
            ZONES='zones=["us-central1-a"]'
            NODE_NUMBER=1
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
        "c4-highmem-2-multi-zone")
            echo "you chose ${opt}"
            MACHINE_TYPE="c4-highmem-2"
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem-singlebroker-zonal.yaml"
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
            MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem-arm-singlebroker-zonal.yaml"
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
            MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem-singlebroker-zonal.yaml"
            PERFTEST_MANIFEST_FILE="kafka-kraft/perftest-zonal.yaml"
            NODE_NUMBER=1
            TOPIC_REPLICATION_FACTOR=1
            TEST_TYPE="1Ldr1Br3z"
            break
            ;;        
        "c4-highmem-2-single-node")
            echo "you chose ${opt}"
            MACHINE_TYPE="c4-highmem-2"
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-single-2cpu-himem.yaml"
            ZONES='zones=["us-central1-a"]'
            NODE_NUMBER=1
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
        "c4d-highmem-2-single-node")
            echo "you chose choice $REPLY which is $opt"
            MACHINE_TYPE="c4d-highmem-2"
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-single-2cpu-himem.yaml"
            ZONES='zones=["us-central1-a"]'
            NODE_NUMBER=1
            break
            ;;
        "c3d-standard-4")
            echo "you chose choice $REPLY which is $opt"
            MACHINE_TYPE=$opt
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-4cpu-x64.yaml"
            break
            ;;
        "c3d-standard-4-single-node")
            echo "you chose choice $REPLY which is $opt"
            MACHINE_TYPE="c3d-standard-4"
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-single-4cpu-x64.yaml"
            ZONES='zones=["us-central1-a"]'
            NODE_NUMBER=1
            break
            ;;
        "c3d-standard-4-single-node-3LG")
            echo "you chose choice $REPLY which is $opt"
            MACHINE_TYPE="c3d-standard-4"
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/kafka-single-4cpu-x64.yaml"
            PERFTEST_MANIFEST_FILE="kafka-kraft/perftest-3-single-node.yaml"
            ZONES='zones=["us-central1-a"]'
            NODE_NUMBER=1
            PERFTEST_REPLICAS=3
            TEST_TYPE="3Ldr3Br"
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
    --var region=$REGION \
    --var kafka_max_count=$NODE_NUMBER \
    --var kafka_image_type=$NODE_IMAGE_TYPE

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




cat << EOF > $TEST_RESULTS
Kafka performance test
Machine type, $MACHINE_TYPE
PD filesystem, $PD_FILE_SYSTEM
Node image type, $NODE_IMAGE_TYPE
Test date and time, $(date '+%Y-%m-%d %H:%M:%S')
Tuning steps:
provisioned-throughput-on-create, 400Mi
provisioned-iops-on-create, 6000
Dataplane v2

EOF

cp $TEST_RESULTS $TEST_RESULTS_CSV


case $TEST_TYPE in
    "1Ldr3Br")
        kubectl apply -f $PERFTEST_MANIFEST_FILE -n $NAMESPACE
        for run in {0..2}
        do
            kubectl apply -f $MANIFEST_FILE -n $NAMESPACE
            for (( pod=0; pod<$NODE_NUMBER; pod++ ))
            do
                kubectl wait --for=condition=Ready pod/kafka-$pod -n $NAMESPACE --timeout=1200s
            done

            sleep 30

            kubectl cp test.sh kafka-perftest:/opt/kafka -n $NAMESPACE
            kubectl exec -it kafka-perftest -n $NAMESPACE -- chmod +x /opt/kafka/test.sh 
            kubectl exec -it kafka-perftest -n $NAMESPACE -- bash -c "/opt/kafka/test.sh kafka-svc.kafka.svc.cluster.local:9092 test-topic-0 $NUMRECORDS $NODE_NUMBER" |tee -a $TEST_RESULTS

            kubectl delete -f $MANIFEST_FILE -n $NAMESPACE
            sleep 30
        done
        kubectl delete -f kafka-kraft/hd-balanced-$PD_FILE_SYSTEM.yaml

        ./result_parser.sh $TEST_RESULTS >>$TEST_RESULTS_CSV

        gsutil cp $TEST_RESULTS  gs://$GCSBUCKET/kafka/gke/$TEST_FILE_EXT-$OS_TYPE-$PD_FILE_SYSTEM-$(date +"%Y_%m_%d_%I_%M_%p").txt
        gsutil cp $TEST_RESULTS_CSV  gs://$GCSBUCKET/kafka/gke/csv/$TEST_FILE_EXT-$OS_TYPE-$PD_FILE_SYSTEM-$(date +"%Y_%m_%d_%I_%M_%p").csv
        ;;

      "3Ldr3Br") 
        kubectl apply -f $PERFTEST_MANIFEST_FILE -n $NAMESPACE
        kubectl apply -f $MANIFEST_FILE -n $NAMESPACE
        for (( pod=0; pod<$NODE_NUMBER; pod++ ))
        do
            kubectl wait --for=condition=Ready pod/kafka-$pod -n $NAMESPACE --timeout=1200s
        done

        sleep 30

        for run in {0..2}
        do
        kubectl cp test.sh kafka-perftest-$run:/opt/kafka -n $NAMESPACE
        kubectl exec -it kafka-perftest-$run -n $NAMESPACE -- chmod +x /opt/kafka/test.sh 
        done

        kubectl exec -it kafka-perftest-0 -n $NAMESPACE -- bash -c "/opt/kafka/test.sh kafka-svc.kafka.svc.cluster.local:9092 test-topic-0 $NUMRECORDS $TOPIC_REPLICATION_FACTOR" > "$TEST_RESULTS-0" 2>&1 &
        kubectl exec -it kafka-perftest-1 -n $NAMESPACE -- bash -c "/opt/kafka/test.sh kafka-svc.kafka.svc.cluster.local:9092 test-topic-1 $NUMRECORDS $TOPIC_REPLICATION_FACTOR" >  "$TEST_RESULTS-1" 2>&1 &
        kubectl exec -it kafka-perftest-2 -n $NAMESPACE -- bash -c "/opt/kafka/test.sh kafka-svc.kafka.svc.cluster.local:9092 test-topic-2 $NUMRECORDS $TOPIC_REPLICATION_FACTOR" |tee  "$TEST_RESULTS-2"

        wait

        for i in {0..2} 
        do
        ./result_parser.sh $TEST_RESULTS-$i >>$TEST_RESULTS_CSV
        cat $TEST_RESULTS-$i >>$TEST_RESULTS
        done

        gsutil cp $TEST_RESULTS  gs://$GCSBUCKET/kafka/gke/$TEST_FILE_EXT-ub$PD_FILE_SYSTEM-$(date +"%Y_%m_%d_%I_%M_%p").txt
        gsutil cp $TEST_RESULTS_CSV  gs://$GCSBUCKET/kafka/gke/csv/$TEST_FILE_EXT-ub$PD_FILE_SYSTEM-$(date +"%Y_%m_%d_%I_%M_%p").csv
        #  rm $TEST_RESULTS
        kubectl delete -f $MANIFEST_FILE -n $NAMESPACE
        ;;
      "1Ldr1Br3z")
        for zone in $DEPLOY_ZONES
        do          
            
            echo "Ruunin test in zone $zone"
            cat $PERFTEST_MANIFEST_FILE | sed "s/{{ZONE}}/$zone/g" | kubectl apply -n $NAMESPACE -f -
            cat $MANIFEST_FILE | sed "s/{{ZONE}}/$zone/g" | kubectl apply -n $NAMESPACE -f -
            pod_number=$(kubectl get statefulset kafka -n kafka -o=jsonpath='{.spec.replicas}')
            for (( pod=0; pod<pod_number; pod++ ))
            do
                kubectl wait --for=condition=Ready pod/kafka-$pod -n $NAMESPACE --timeout=1200s
            done

            sleep 30

            kubectl cp test.sh kafka-perftest:/opt/kafka -n $NAMESPACE
            kubectl exec -it kafka-perftest -n $NAMESPACE -- chmod +x /opt/kafka/test.sh 
            kubectl exec -it kafka-perftest -n $NAMESPACE -- bash -c "/opt/kafka/test.sh kafka-svc.kafka.svc.cluster.local:9092 test-topic-0 $NUMRECORDS $TOPIC_REPLICATION_FACTOR" |tee -a $zone-$TEST_RESULTS
            
            echo >>$TEST_RESULTS_CSV
            echo "Zone, $zone" >>$TEST_RESULTS_CSV
            echo >>$TEST_RESULTS_CSV

            echo >>$TEST_RESULTS
            echo "Zone: $zone" >>$TEST_RESULTS
            echo >>$TEST_RESULTS

            ./result_parser.sh $zone-$TEST_RESULTS >>$TEST_RESULTS_CSV
            cat $zone-$TEST_RESULTS >>$TEST_RESULTS
            rm $zone-$TEST_RESULTS
            cat $PERFTEST_MANIFEST_FILE | sed "s/{{ZONE}}/$zone/g" | kubectl delete -n $NAMESPACE -f -
            cat $MANIFEST_FILE | sed "s/{{ZONE}}/$zone/g" | kubectl delete -n $NAMESPACE -f -
            kubectl wait --for=delete statefulset/kafka -n $NAMESPACE
            kubectl wait --for=delete pod/kafka-perftest -n $NAMESPACE
        done

        kubectl delete -f kafka-kraft/hd-balanced-$PD_FILE_SYSTEM.yaml

        gsutil cp $TEST_RESULTS  gs://$GCSBUCKET/kafka/gke/$TEST_FILE_EXT-$OS_TYPE-$PD_FILE_SYSTEM-$(date +"%Y_%m_%d_%I_%M_%p").txt
        gsutil cp $TEST_RESULTS_CSV  gs://$GCSBUCKET/kafka/gke/csv/$TEST_FILE_EXT-$OS_TYPE-$PD_FILE_SYSTEM-$(date +"%Y_%m_%d_%I_%M_%p").csv
        ;;
    esac



