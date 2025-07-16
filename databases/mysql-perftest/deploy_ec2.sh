#!/bin/zsh

source aws_common.sh

# Create clusters
terraform -chdir=terraform/aws/ec2-cluster init
terraform -chdir=terraform/aws/ec2-cluster validate
terraform -chdir=terraform/aws/ec2-cluster apply -var-file=common.tfvars