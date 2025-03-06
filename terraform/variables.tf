variable "aws_region" {
  default     = "us-east-1"
}

variable "ecr_repo_name" {
  type    = string
  default = "k8s-app"
}