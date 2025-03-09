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
  retention_in_days = 1                                          # Set the desired retention period (e.g., 30 days)
}

resource "aws_eks_cluster" "eks" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.32"

  vpc_config {
    subnet_ids = data.aws_subnets.eks_subnet.ids
  }
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  depends_on                = [aws_cloudwatch_log_group.eks_cluster_logs]
}

data "aws_ami" "eks_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amazon-eks-node-al2023-x86_64-standard-1.32*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["602401143452"] # Canonical owner for   Amazon
}


resource "aws_launch_template" "eks_nodes" {
  name          = "eks-nodes-template"
  image_id      = data.aws_ami.eks_ami.id # Use the correct EKS-optimized AMI
  instance_type = "t3.medium"
  block_device_mappings {
    device_name = "/dev/xvda" 
    ebs {
      volume_size = 20
    }
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional" # Allow both IMDSv1 and IMDSv2
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name      = "eks_cluster_node_instance"
      Terraform = "yes"
    }
  }
}



resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "single-node"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = data.aws_subnets.eks_subnet.ids
  #instance_types  = ["t3.medium"] # if not in launch template
  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }
  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = "$Latest"
  }
  #disk_size = 20 #if not defined in the launch templated
  tags = {
    "Terraform" = "yes"
  }
}
