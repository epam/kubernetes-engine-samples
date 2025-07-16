#!/bin/zsh

source aws_common.sh

terraform -chdir=terraform/aws/ec2-cluster  destroy -var-file=common.tfvars