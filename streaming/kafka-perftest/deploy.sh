#!/bin/zsh

source common.sh

# Create clusters
terraform -chdir=terraform/gke-standard init
terraform -chdir=terraform/gke-standard apply \
    --auto-approve \
    --var project_id=$PROJECT_ID \
    --var cluster_prefix=${KUBERNETES_CLUSTER_PREFIX}

# Get cluster credentials
gcloud container clusters get-credentials ${KUBERNETES_CLUSTER_PREFIX}-cluster --region ${REGION}

NAMESPACE=$KUBERNETES_CLUSTER_PREFIX

kubectl create ns $NAMESPACE

helm repo add strimzi https://strimzi.io/charts/
helm install strimzi-operator strimzi/strimzi-kafka-operator -n $NAMESPACE

sleep 180
kubectl apply -f 06-kraft/hd-balanced.yaml -n $NAMESPACE
kubectl apply -f 06-kraft/my-cluster.yaml -n $NAMESPACE