#!/bin/zsh

source ~/.ssh/aws_common.sh

cd terraform/aws/eks3
# sed -ie 's/"deletion_protection": true/"deletion_protection": false/g' terraform.tfstate
# terraform destroy -target=module.eks_cluster
terraform destroy
cd -
