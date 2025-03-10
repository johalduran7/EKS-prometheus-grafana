output "eks_cluster_name" {
  value = var.eks_cluster_name
}

output "aws_region" {
  value = var.aws_region
}

output auto_scaling_groups {
  value       = aws_eks_node_group.eks_nodes.resources
}

