# If you want to create a custom Launch Template. 

# resource "aws_iam_instance_profile" "eks_ec2_instance_profile" {
#   name = "eks-ec2-instance-profile"
#   role = aws_iam_role.eks_node_role.name
# }


# resource "aws_launch_template" "eks_nodes" {
#   name          = "eks-nodes-template"
#   image_id      = data.aws_ami.eks_ami.id # Use the correct EKS-optimized AMI
#   instance_type = "t3.medium"
#   block_device_mappings {
#     device_name = "/dev/xvda"
#     ebs {
#       volume_size = 20
#       volume_type           = "gp3"
#       delete_on_termination = true
#     }
#   }

#   # iam_instance_profile {
#   #   name = aws_iam_instance_profile.eks_ec2_instance_profile.name
#   # }

#   metadata_options {
#     http_tokens                 = "optional"
#     http_put_response_hop_limit = 1
#     instance_metadata_tags      = "disabled"
#   }

#   #vpc_security_group_ids = [aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id] # Use the correct security group

#   network_interfaces {
#     device_index                = 0
#     security_groups             = [aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id]
#   }
#   user_data = base64encode(<<-EOT
#     #!/bin/bash
#     set -o xtrace

#     /etc/eks/bootstrap.sh my-cluster
#   EOT
#   )
#   tag_specifications {
#     resource_type = "instance"
#     tags = {
#       Name                 = "eks_cluster_node_instance"
#       Terraform            = "yes"
#       "eks:nodegroup-name" = var.eks_node_group_name
#       "eks:cluster-name"   = var.eks_cluster_name
#     }
#   }
#   tag_specifications {
#     resource_type = "volume"
#     tags = {
#       Terraform            = "yes"
#       "eks:nodegroup-name" = var.eks_node_group_name
#       "eks:cluster-name"   = var.eks_cluster_name
#     }
#   }
#   tag_specifications {
#     resource_type = "network-interface"
#     tags = {
#       Terraform            = "yes"
#       "eks:nodegroup-name" = var.eks_node_group_name
#       "eks:cluster-name"   = var.eks_cluster_name
#     }
#   }
# }



# resource "aws_eks_node_group" "eks_nodes" {
#   cluster_name    = aws_eks_cluster.eks.name
#   node_group_name = var.eks_node_group_name
#   node_role_arn   = aws_iam_role.eks_node_role.arn
#   subnet_ids      = data.aws_subnets.eks_subnet.ids
#   #instance_types  = ["t3.medium"] # if not in launch template
#   scaling_config {
#     desired_size = 1
#     max_size     = 1
#     min_size     = 1
#   }
#   launch_template {
#     id      = aws_launch_template.eks_nodes.id
#     version = "$Latest"
#   }
#   #disk_size = 20 #if not defined in the launch templated
#   # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
#   # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
#   depends_on = [
#     aws_iam_role_policy_attachment.eks_worker_node_policy,
#     aws_iam_role_policy_attachment.eks_ec2_registry_readonly,
#     aws_iam_role_policy_attachment.eks_CNI_policy
#   ]
#   tags = {
#     "Terraform" = "yes"
#   }
# }