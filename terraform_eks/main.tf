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
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "disabled"
  }

  vpc_security_group_ids = [aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id] # Use the correct security group


  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                 = "eks_cluster_node_instance"
      Terraform            = "yes"
      "eks:nodegroup-name" = "${var.eks_node_group_name}"
      "eks:cluster-name"   = "${var.eks_cluster_name}"
    }
  }
  tag_specifications {
    resource_type = "volume"
    tags = {
      Terraform            = "yes"
      "eks:nodegroup-name" = "${var.eks_node_group_name}"
      "eks:cluster-name"   = "${var.eks_cluster_name}"
    }
  }
  tag_specifications {
    resource_type = "network-interface"
    tags = {
      Terraform            = "yes"
      "eks:nodegroup-name" = "${var.eks_node_group_name}"
      "eks:cluster-name"   = "${var.eks_cluster_name}"
    }
  }
}



resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = var.eks_node_group_name
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
  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_ec2_registry_readonly,
    aws_iam_role_policy_attachment.eks_CNI_policy
  ]
  tags = {
    "Terraform" = "yes"
  }
}

