terraform {
  required_version = ">= 1.10.2" # Ensure your Terraform CLI is this version or higher

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.91"
    }
    kubernetes = { # Add Kubernetes provider
      source  = "hashicorp/kubernetes"
      version = ">= 2.23.0" # Use a recent stable version, adjust as needed
    }
  }
}