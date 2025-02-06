#!/bin/zsh

source common.sh

# Create clusters
terraform -chdir=terraform/gce-cluster init
terraform -chdir=terraform/gce-cluster validate
terraform -chdir=terraform/gce-cluster apply \
    --var project_id=$PROJECT_ID