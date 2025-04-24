variable "create_iam_role" {
  description = "Determines whether an IAM role is created for the cluster"
  type        = bool
  default     = true
}

variable "iam_role_arn" {
  description = "Existing IAM role ARN for the cluster. Required if `create_iam_role` is set to `false`"
  type        = string
  default     = "arn:aws:iam::559050221754:role/aws-service-role/eks.amazonaws.com/AWSServiceRoleForAmazonEKS"
}

variable "create_node_iam_role" {
  description = "Determines whether an EKS Auto node IAM role is created"
  type        = bool
  default     = true
}

variable "node_iam_role_name" {
  description = "Name to use on the EKS Auto node IAM role created"
  type        = string
  default     = "arn:aws:iam::aws:policy/aws-service-role/AWSServiceRoleForAmazonEKSNodegroup"
}

variable "iam_role_permissions_boundary" {
  description = "ARN of the policy that is used to set the permissions boundary for the IAM role"
  type        = string
  default     = "arn:aws:iam::559050221754:policy/eo_role_boundary"
}

variable "cluster_endpoint_public_access" {
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks which can access the Amazon EKS public API server endpoint"
  type        = list(string)
  default     = ["85.223.209.0/24"]
}

variable "kafka_node_pool_instance_type" {
  description = "The VM instance type for kafka node pool"
  default     = "r7i.large"
}

variable "kafka_ami_type" {
  description = "The AMI type for kafka node pool"
  default = "AL2_x86_64"
}

variable "azs" {
  description = "Zones to use for EKS"
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}