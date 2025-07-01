resource "aws_ecr_repository" "k8s-app" {
  name                 = "${var.ecr_repo_name}"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}


resource "aws_ecr_lifecycle_policy" "ecr_k8s-app-policy" {
  repository = aws_ecr_repository.k8s-app.name

  policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep only the latest two images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 1
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}


# Null resource to build and push the Docker image
resource "null_resource" "build_and_push_k8s-app-image" {
  triggers = {
    # Rebuild the image if the Dockerfile changes
    dockerfile_hash = filemd5("../app//Dockerfile")
    app_js_hash     = filemd5("../app/app.js")
  }

  provisioner "local-exec" {
    command = <<EOT
      # Authenticate Docker to ECR
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.k8s-app.repository_url}

      # Build the Docker image
      docker build -t ${aws_ecr_repository.k8s-app.repository_url}:${var.container_tag} -f ../app//Dockerfile ../app

      # Push the Docker image to ECR
      docker push ${aws_ecr_repository.k8s-app.repository_url}:${var.container_tag}
    EOT
  }

}