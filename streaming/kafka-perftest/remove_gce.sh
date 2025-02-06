#!/bin/zsh

source common.sh

terraform -chdir=terraform/gce-cluster destroy --var project_id=$PROJECT_ID