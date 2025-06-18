#!/bin/zsh
set -e

source common.sh

cd terraform/gke-standard
export MASTER_IPV4_CIDR_BLOCK="172.16.0.0/28"
gcloud container clusters get-credentials mysql-cluster --region us-central1
# sed -ie 's/"deletion_protection": true/"deletion_protection": false/g' terraform.tfstate
echo "--> Deleting namespaces: mysql-tuned, mysql..."
kubectl delete namespace mysql-tuned mysql --ignore-not-found=true

echo "--> Waiting for namespaces to be fully terminated. This may take a few minutes..."
#Loop while either of the 'get namespace' commands succeeds (meaning at least one namespace still exists).
while kubectl get namespace mysql-tuned &> /dev/null || kubectl get namespace mysql &> /dev/null; do
  echo -n "." # Show progress by printing a dot
  sleep 10
done
terraform destroy --auto-approve --var project_id=$PROJECT_ID --var master_ipv4_cidr_block=$MASTER_IPV4_CIDR_BLOCK
cd -
