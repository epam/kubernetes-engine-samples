# variable "machine_type" {
#   description = "Machine type for Kafka brokers and load generator"
#   type        = string
#   default     = ""
# }

# variable "ami_id" {
#   description = "Image OS type for Kafka brokers and load generator"
#   type        = string
#   default     = ""
# }

# variable "subnet_id" {
#   description = "Subnet ID for single zone testing"
#   type        = string
#   default     = ""
# }

variable "region" {
  description = "AWS region to deploy all resources in."
  type        = string
  default     = "us-east-1"   # change or remove the default
}

variable "server_machine_type" {
  description = "EC2 instance type for MySQL servers."
  type        = string
  default     = "r7a.4xlarge"
}

variable "common_ami_id" {
  description = "AMI ID for MySQL load-generator instances."
  type        = string
}

variable "loader_machine_type" {
  description = "EC2 instance type for load-generators."
  type        = string
  default     = "r7a.4xlarge"
}

variable "s3_bucket_name" {
  description = "Name of the already-created S3 bucket that will store benchmark results."
  type        = string
}