variable "vpc_cidr" {
  description = "The IP addresses range for VPC"
  default     = "10.10.0.0/16"
}

variable "availability_zones" {
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}