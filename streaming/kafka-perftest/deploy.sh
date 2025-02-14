#!/bin/bash

source common.sh

PS3='Please enter your choice: '
options=("c4a-highmem-2" "c4-highmem-2" "c4d-highmem-2" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "c4a-highmem-2")
            echo "you chose ${opt}"
            MACHINE_TYPE=$opt
            MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem-arm.yaml"
            break
            ;;
        "c4-highmem-2")
            echo "you chose ${opt}"
            MACHINE_TYPE=$opt
            MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem.yaml"
            break
            ;;
        "c4d-highmem-2")
            echo "you chose choice $REPLY which is $opt"
            MACHINE_TYPE=$opt
            MANIFEST_FILE="kafka-kraft/kafka-2cpu-himem.yaml"
            break
            ;;
        "Quit")
            exit
            ;;
        *) echo "invalid option $REPLY";;
    esac
done


# Create clusters
terraform -chdir=terraform/gke-standard init
terraform -chdir=terraform/gke-standard apply \
    --auto-approve \
    --var project_id=$PROJECT_ID \
    --var cluster_prefix=${KUBERNETES_CLUSTER_PREFIX} \
    --var kafka_node_pool_instance_type=$MACHINE_TYPE

# Get cluster credentials
# gcloud container clusters get-credentials ${KUBERNETES_CLUSTER_PREFIX}-cluster --region ${REGION}

gcloud container clusters get-credentials ${KUBERNETES_CLUSTER_PREFIX}-cluster --region ${REGION}  


NAMESPACE=$KUBERNETES_CLUSTER_PREFIX

kubectl create ns $NAMESPACE

kubectl apply -f kafka-kraft/hd-balanced.yaml
kubectl apply -f $MANIFEST_FILE -n $NAMESPACE

kubectl apply -f kafka-kraft/perftest.yaml -n $NAMESPACE

kubectl wait --for=condition=Ready pod/kafka-0 -n $NAMESPACE --timeout=600s
kubectl wait --for=condition=Ready pod/kafka-1 -n $NAMESPACE --timeout=600s
kubectl wait --for=condition=Ready pod/kafka-2 -n $NAMESPACE --timeout=600s


kubectl cp test.sh kafka-perftest:/opt/kafka -n $NAMESPACE
kubectl exec -it kafka-perftest -n $NAMESPACE -- chmod +x /opt/kafka/test.sh 
kubectl exec -it kafka-perftest -n $NAMESPACE -- bash -c "/opt/kafka/test.sh"

kubectl cp kafka-perftest:testresults.txt testresults.txt -n kafka
gsutil cp testresults.txt  gs://benchmark-results-hl2-gogl-wopt-t1iylu/kafka/gke/$MACHINE_TYPE-$(date +"%Y_%m_%d_%I_%M_%p").txt

kubectl delete -f $MANIFEST_FILE -n $NAMESPACE
#kubectl cp kafka-perftest:/opt/kafka/testresults.txt testresults.txt -n kafka
