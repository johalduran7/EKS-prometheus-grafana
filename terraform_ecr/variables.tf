variable "aws_region" {
  default     = "us-east-1"
}

variable "ecr_repo_name" {
  type    = string
  default = "k8s-app"
}

variable "container_tag" {
  type    = string
  default = "2.1.0"
}