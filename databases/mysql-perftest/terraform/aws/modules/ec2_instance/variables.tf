variable "ami_id" {
  description = "AMI ID to use for the EC2 instances."
  type        = string
}

variable "machine_type" {
  description = "EC2 instance type (e.g., t3.large, m7i.xlarge)."
  type        = string
}

variable "instance_count" {
  description = "Number of EC2 instances to create (per call to the module)."
  type        = number
  default     = 1
}

variable "name_prefix" {
  description = "Prefix used for the Name tag (e.g., mysql-server-0)."
  type        = string
}

# Networking
variable "subnet_ids" {
  description = "List of subnet IDs; instances are balanced across them."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups to attach. Leave empty to inherit the default."
  type        = list(string)
  default     = []
}

# variable "iam_instance_profile" {
#   description = "Optional IAM instance-profile providing permissions (e.g., SSM)."
#   type        = string
#   default     = null
# }

# Root volume 
variable "root_volume_size" {
  description = "Size (GiB) of the root EBS volume."
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Root EBS volume type (gp3 recommended)."
  type        = string
  default     = "gp3"
}

variable "root_volume_iops" {
  description = "IOPS for gp3 root volume. Ignored for other types."
  type        = number
  default     = 3000
}

variable "root_volume_throughput" {
  description = "Throughput (MiB/s) for gp3 root volume. Ignored for other types."
  type        = number
  default     = 125
}

# Optional single data disk
variable "use_data_disk" {
  description = "Attach an additional /dev/sdb EBS data disk."
  type        = bool
  default     = false
}

variable "data_volume_size" {
  description = "Size (GiB) of the data disk if enabled."
  type        = number
  default     = 500
}

variable "data_volume_type" {
  description = "EBS volume type for the data disk."
  type        = string
  default     = "gp3"
}

variable "data_volume_iops" {
  description = "IOPS for data disk."
  type        = number
  default     = 16000
}

variable "data_volume_throughput" {
  description = "Throughput (MiB/s) for gp3 data disk. Ignored for other types."
  type        = number
  default     = 250
}

# User-data templating
variable "user_data_template" {
  description = "Path to a shell-script template rendered via templatefile(). Null to skip."
  type        = string
  default     = null
}

variable "user_data_vars" {
  description = "Map of variables passed into the user-data template."
  type        = map(string)
  default     = {}
}
