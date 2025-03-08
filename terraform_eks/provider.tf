provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "us-east-2"
  region = "us-east-2"
}
