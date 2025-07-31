module "eks_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "mysql-sysbench-eks-3"
  cluster_version = "1.32"
  create_iam_role = var.create_iam_role
  iam_role_permissions_boundary = var.iam_role_permissions_boundary
  cluster_endpoint_public_access = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # EKS Addons
  cluster_addons = {
    coredns            = {}
    eks-pod-identity-agent = {}
    kube-proxy         = {}
    vpc-cni            = {}
    aws-ebs-csi-driver = { most_recent = true }
    # amazon-cloudwatch-observability = { # Розкоментуйте, якщо хочете деплоїти аддон через Terraform
    #   most_recent = true
    # }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    mysql = {
      name           = "mysql-nodepool"
      ami_type       = var.mysql_ami_type
      instance_types = [var.mysql_node_pool_instance_type]

      min_size       = 1
      max_size       = 1
      desired_size   = 1
      create_iam_role = var.create_node_iam_role
      iam_role_permissions_boundary = var.iam_role_permissions_boundary
      create_iam_instance_profile = true

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      }
      tags = { app = "mysql-app" }
      labels = { app = "mysql-app" }
    }
    mysql-tuned = {
      name           = "mysql-tuned-nodepool"
      ami_type       = var.mysql_ami_type
      instance_types = [var.mysql_node_pool_instance_type]

      min_size       = 1
      max_size       = 1
      desired_size   = 1
      create_iam_role = var.create_node_iam_role
      iam_role_permissions_boundary = var.iam_role_permissions_boundary
      create_iam_instance_profile = true

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      }
      tags = { app = "mysql-app-tuned" }
      labels = { app = "mysql-app-tuned" }
    }
    sysbench = {
      name           = "sb-ndpl"
      ami_type       = var.sysbench_ami_type
      instance_types = [var.sysbench_node_pool_instance_type]

      min_size       = 1
      max_size       = 1
      desired_size   = 1
      create_iam_role = var.create_node_iam_role
      iam_role_permissions_boundary = var.iam_role_permissions_boundary
      create_iam_instance_profile = true

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      }
      tags = { app = "sysbench-app" }
      labels = { app = "sysbench-app" }
    }
    sysbench-tuned = {
      name           = "sb-tuned-ndpl"
      ami_type       = var.sysbench_ami_type
      instance_types = [var.sysbench_node_pool_instance_type]

      min_size       = 1 
      max_size       = 1
      desired_size   = 1
      create_iam_role = var.create_node_iam_role
      iam_role_permissions_boundary = var.iam_role_permissions_boundary
      create_iam_instance_profile = true

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      }
      tags = { app = "sysbench-tuned-app" }
      labels = { app = "sysbench-tuned-app" } # Label for nodeSelector for tuned sysbench
    }
  }

  tags = local.tags
}

resource "aws_eks_access_policy_association" "example" {
  cluster_name  = module.eks_cluster.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  principal_arn = "arn:aws:iam::559050221754:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdminUser_effe09bf72adebda"
  access_scope {
    type      = "cluster"
  }
}

resource "aws_eks_access_policy_association" "example_1" {
  cluster_name  = module.eks_cluster.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = "arn:aws:iam::559050221754:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdminUser_effe09bf72adebda"
  access_scope {
    type      = "cluster"
  }
}

resource "aws_eks_access_entry" "example" {
  cluster_name  = module.eks_cluster.cluster_name
  principal_arn = "arn:aws:iam::559050221754:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdminUser_effe09bf72adebda"
  type          = "STANDARD"
}