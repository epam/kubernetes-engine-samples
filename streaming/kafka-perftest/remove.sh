#!/bin/zsh

source common.sh

kubectl delete -f kafka-kraft/kafka.yaml -n kafka


cd terraform/gke-standard
# sed -ie 's/"deletion_protection": true/"deletion_protection": false/g' terraform.tfstate
terraform destroy --auto-approve --var project_id=$PROJECT_ID
cd -
