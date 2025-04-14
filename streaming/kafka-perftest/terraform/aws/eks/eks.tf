module "eks_bottlerocket" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "kafka"
  cluster_version = "1.32"
  create_iam_role = var.create_iam_role
  iam_role_permissions_boundary = var.iam_role_permissions_boundary
  cluster_endpoint_public_access = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs


  # EKS Addons
  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
    aws-ebs-csi-driver = { most_recent = true }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    kafka-brokers = {
      name          = "brokers" 
      ami_type      = var.kafka_ami_type
      instance_types = [var.kafka_node_pool_instance_type]

      min_size = 2
      max_size = 3
      # This value is ignored after the initial creation
      # https://github.com/bryantbiggs/eks-desired-size-hack
      desired_size = 3
      create_iam_role = var.create_node_iam_role
      iam_role_permissions_boundary = var.iam_role_permissions_boundary
      create_iam_instance_profile = true
      iam_role_additional_policies = { AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy" }
      tags = { app="kafka" }
      labels = {app="kafka" }
    }
    kafka-perftest = {
      name          = "perftest"
      ami_type      = "AL2_x86_64"
      instance_types = ["r7i.large"]

      min_size = 1
      max_size = 3
      # This value is ignored after the initial creation
      # https://github.com/bryantbiggs/eks-desired-size-hack
      desired_size = 3
      create_iam_role = var.create_node_iam_role
      iam_role_permissions_boundary = var.iam_role_permissions_boundary
      create_iam_instance_profile = true
      tags = { app="perftest" }
      labels = { app="perftest" }
    }
  }

  eks_managed_node_group_defaults={
    kafka-brokers = {
      labels={app="kafka"}
      },
    kafka-perftest = {
      labels={app="perftest", type="testing"}
    }
  }
  

  tags = local.tags
}

resource "aws_eks_access_policy_association" "example" {
  cluster_name  = module.eks_bottlerocket.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  principal_arn =  "arn:aws:iam::559050221754:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdminUser_effe09bf72adebda"
  access_scope {
    type       = "cluster"
  }
}

resource "aws_eks_access_policy_association" "example_1" {
  cluster_name  = module.eks_bottlerocket.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn =  "arn:aws:iam::559050221754:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdminUser_effe09bf72adebda"
  access_scope {
    type       = "cluster"
  }
}

resource "aws_eks_access_entry" "example" {
  cluster_name      = module.eks_bottlerocket.cluster_name
  principal_arn     = "arn:aws:iam::559050221754:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdminUser_effe09bf72adebda"
  type              = "STANDARD"
}