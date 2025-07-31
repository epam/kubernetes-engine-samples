#!/bin/bash

MACHINE_TYPE="r7i.8xlarge"
SYSBENCH_MACHINE_TYPE="m7i.8xlarge"
AMI_TYPE="BOTTLEROCKET_x86_64"

# Terraform execution for infrastructure
echo "--- Initializing Terraform ---"
terraform -chdir=terraform/aws/eks init

echo "--- Applying Terraform (Remaining Resources) ---"
terraform -chdir=terraform/aws/eks apply --auto-approve \
    --var mysql_node_pool_instance_type="$MACHINE_TYPE" \
    --var mysql_ami_type="$AMI_TYPE" \
    --var sysbench_node_pool_instance_type="$SYSBENCH_MACHINE_TYPE" \
    --var sysbench_ami_type="$AMI_TYPE"

# Get cluster credentials for mysql-sysbench-eks (Intel) cluster
echo "--- Updating kubeconfig ---"
aws eks update-kubeconfig --name mysql-sysbench-eks --region us-east-1

# Kubernetes resource deployment
echo "--- Deploying Kubernetes Namespaces ---"
kubectl apply -f mysql/aws/mysql-namespace.yaml
kubectl apply -f mysql/aws/mysql-tuned-namespace.yaml

echo "--- Deploying gp3 StorageClasses ---"
kubectl apply -f mysql/aws/balanced-storage-base.yaml
kubectl apply -f mysql/aws/balanced-storage-tuned.yaml

# echo "--- Deploying io2 StorageClasses ---"
# kubectl apply -f mysql/aws/balanced-storage-base-io.yaml
# kubectl apply -f mysql/aws/balanced-storage-tuned-io.yaml

echo "--- Deploying MySQL Secrets ---"
kubectl apply -f mysql/aws/mysql-ssl-certs.yaml -n mysql
kubectl apply -f mysql/aws/mysql-tuned-ssl-certs.yaml -n mysql-tuned
kubectl apply -f mysql/aws/mysql-secret.yaml -n mysql
kubectl apply -f mysql/aws/mysql-tuned-secret.yaml -n mysql-tuned
kubectl apply -f mysql/aws/mysql-configmap.yaml -n mysql
kubectl apply -f mysql/aws/mysql-tuned-configmap.yaml -n mysql-tuned

echo "--- Deploying MySQL (base) ---"
kubectl apply -f mysql/aws/mysql-service.yaml -n mysql
kubectl apply -f mysql/aws/mysql-statefulset.yaml -n mysql

echo "--- Deploying MySQL (tuned) ---"
kubectl apply -f mysql/aws/mysql-tuned-service.yaml -n mysql-tuned
kubectl apply -f mysql/aws/mysql-tuned-statefulset.yaml -n mysql-tuned

sleep 160

#Deploy x86_64 Sysbench version
echo "--- Deploying Sysbench (base) ---"
kubectl apply -f mysql/aws/sysbench-statefulset.yaml -n mysql

echo "--- Deploying Sysbench (tuned) ---"
kubectl apply -f mysql/aws/sysbench-tuned-statefulset.yaml -n mysql-tuned