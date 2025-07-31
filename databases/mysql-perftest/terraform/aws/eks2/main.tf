provider "aws" {
  region = local.region
}

# Kubernetes Provider
provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
  # Optionally: if you have a local kubeconfig you want to use for debugging
  # config_path            = "~/.kube/config" 
  # config_context         = "arn:aws:eks:us-east-1:660150332865:cluster/mysql-sysbench-eks" # Change to your cluster context if using local kubeconfig
}

# Data source for Kubernetes authentication token
data "aws_eks_cluster_auth" "this" {
  name = module.eks_cluster.cluster_name
}

data "aws_availability_zones" "available" {
  # Exclude local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name   = "ex-self-mng"
  region = "us-east-1"

  vpc_cidr = "10.0.0.0/16"
  # azs      = slice(data.aws_availability_zones.available.names, 0, 3)
  azs  = var.azs
  tags = {
    GithubRepo = "terraform-aws-eks"
    GithubOrg  = "terraform-aws-modules"
  }
}

################################################################################
# VPC
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

  enable_nat_gateway         = true
  single_nat_gateway         = true
  manage_default_network_acl = false

  public_subnet_tags = {
    # "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    # "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}