data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "eks_subnet" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = ["${var.aws_region}a", "${var.aws_region}b"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_cloudwatch_log_group" "eks_cluster_logs" {
  name              = "/aws/eks/${var.eks_cluster_name}/cluster" # Replace with your cluster name
  retention_in_days = 1 # Set the desired retention period (e.g., 30 days)
}

resource "aws_eks_cluster" "eks" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.32"

  vpc_config {
    subnet_ids = data.aws_subnets.eks_subnet.ids
  }
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  depends_on = [aws_cloudwatch_log_group.eks_cluster_logs]
}

resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "single-node"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = data.aws_subnets.eks_subnet.ids
  instance_types  = ["t3.medium"]
  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }
  disk_size = 20
  tags = {
    "Name" = "eks-node-instance"
    "Terraform"="yes"
  }
}
