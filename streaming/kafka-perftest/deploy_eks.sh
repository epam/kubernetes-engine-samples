#!/bin/bash

source common.sh


NODE_NUMBER=3

PERFTEST_MANIFEST_FILE="kafka-kraft/aws/perftest-aws.yaml"
PERFTEST_REPLICAS=3
AMI_TYPE="AL2_x86_64"


# C4A highmem2 -> r8g.large (ARM)
 
# C4 highmem2 -> r7i.large (note: older Intel family compared to GCP - Sapphire)
 
# C3D standard4 -> m7a.xlarge (also AMD EPYC 4th gen)

PS3='Please enter your choice: '
options=(
         "r7i.large" \
         "m7a.xlarge" \
         "r8g.large" \
         "Quit"
        )
select opt in "${options[@]}"
do
    case $opt in
        "r7i.large")
            echo "you chose ${opt}"
            MACHINE_TYPE=$opt
            PERF_MACHINE_TYPE=$opt
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/aws/kafka-2cpu-x64-aws.yaml"
            break
            ;;
        "m7a.xlarge")
            echo "you chose ${opt}"
            MACHINE_TYPE=$opt
            PERF_MACHINE_TYPE=$opt
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/aws/kafka-2cpu-x64-aws.yaml"
            break
            ;;
        "r8g.large")
            echo "you chose ${opt}"
            MACHINE_TYPE=$opt
            PERF_MACHINE_TYPE=$opt
            TEST_FILE_EXT=$opt
            MANIFEST_FILE="kafka-kraft/aws/kafka-2cpu-arm-aws.yaml"
            AMI_TYPE="AL2_ARM_64"
            break
            ;;
        "Quit")
            exit
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

# Create clusters
terraform -chdir=terraform/aws/eks init
terraform -chdir=terraform/aws/eks apply \
    --var kafka_node_pool_instance_type=$MACHINE_TYPE \
    --var kafka_ami_type=$AMI_TYPE

# Get cluster credentials

aws eks update-kubeconfig --name=kafka --region=us-east-1


NAMESPACE="kafka"
TEST_RESULTS=testresults.txt
TEST_RESULTS_CSV=testresults.csv
PD_FILE_SYSTEM=xfs
kubectl create ns $NAMESPACE

#kubectl apply -f kafka-kraft/hd-balanced.yaml
# kubectl apply -f kafka-kraft/hd-balanced-$PD_FILE_SYSTEM.yaml


kubectl apply -f $PERFTEST_MANIFEST_FILE -n $NAMESPACE

cat << EOF > $TEST_RESULTS
Kafka performance test
Machine type, $MACHINE_TYPE
PD filesystem, $PD_FILE_SYSTEM
Node image type, $NODE_IMAGE_TYPE
Test date and time, $(date '+%Y-%m-%d %H:%M:%S')
Disk type: gp2

EOF

cp $TEST_RESULTS $TEST_RESULTS_CSV


case $PERFTEST_REPLICAS in
    1)
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

        gsutil cp $TEST_RESULTS  gs://$GCSBUCKET/kafka/eks/$TEST_FILE_EXT-$OS_TYPE-$PD_FILE_SYSTEM-$(date +"%Y_%m_%d_%I_%M_%p").txt
        gsutil cp $TEST_RESULTS_CSV  gs://$GCSBUCKET/kafka/eks/csv/$TEST_FILE_EXT-$OS_TYPE-$PD_FILE_SYSTEM-$(date +"%Y_%m_%d_%I_%M_%p").csv
        ;;

      3) 
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

        kubectl exec -it kafka-perftest-0 -n $NAMESPACE -- bash -c "/opt/kafka/test.sh kafka-svc.kafka.svc.cluster.local:9092 test-topic-0 $NUMRECORDS 1" > "$TEST_RESULTS-0" 2>&1 &
        kubectl exec -it kafka-perftest-1 -n $NAMESPACE -- bash -c "/opt/kafka/test.sh kafka-svc.kafka.svc.cluster.local:9092 test-topic-1 $NUMRECORDS 1" >  "$TEST_RESULTS-1" 2>&1 &
        kubectl exec -it kafka-perftest-2 -n $NAMESPACE -- bash -c "/opt/kafka/test.sh kafka-svc.kafka.svc.cluster.local:9092 test-topic-2 $NUMRECORDS 1" |tee  "$TEST_RESULTS-2"

        wait

        for i in {0..2} 
        do
        ./result_parser.sh $TEST_RESULTS-$i >>$TEST_RESULTS_CSV
        cat $TEST_RESULTS-$i >>$TEST_RESULTS
        done

        gsutil cp $TEST_RESULTS  gs://$GCSBUCKET/kafka/eks/$TEST_FILE_EXT-ub$PD_FILE_SYSTEM-$(date +"%Y_%m_%d_%I_%M_%p").txt
        gsutil cp $TEST_RESULTS_CSV  gs://$GCSBUCKET/kafka/eks/csv/$TEST_FILE_EXT-ub$PD_FILE_SYSTEM-$(date +"%Y_%m_%d_%I_%M_%p").csv
        #  rm $TEST_RESULTS
        kubectl delete -f $MANIFEST_FILE -n $NAMESPACE
        kubectl delete -f kafka-kraft/hd-balanced-$PD_FILE_SYSTEM.yaml
        ;;
    esac



