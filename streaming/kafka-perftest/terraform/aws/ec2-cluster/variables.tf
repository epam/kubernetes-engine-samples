variable "machine_type" {
  description = "Machine type for Kafka brokers and load generator"
  type        = string
  default     = ""
}

variable "ami_id" {
  description = "Image OS type for Kafka brokers and load generator"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Subnet ID for single zone testing"
  type        = string
  default     = ""
}