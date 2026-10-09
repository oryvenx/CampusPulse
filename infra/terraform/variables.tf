variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "campuspulse"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "dev"
}

variable "admin_cidr" {
  description = "Public IP in CIDR form (for SSH)"
  type        = string
  # set in terraform.tfvars
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Name of an existing EC2 key pair for SSH"
  type        = string
}

variable "github_repo_url" {
  description = "Public Git repo URL the EC2 will clone"
  type        = string
}

variable "sensor_api_key" {
  description = "API key for simulated sensors"
  type        = string
  sensitive   = true
}
