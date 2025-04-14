#!/bin/zsh

source common.sh

cd terraform/aws/eks
# sed -ie 's/"deletion_protection": true/"deletion_protection": false/g' terraform.tfstate
terraform destroy --auto-approve
cd -
