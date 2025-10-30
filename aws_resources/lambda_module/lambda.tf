# Connect with Docker unix socket
provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# ECR repository creation
resource "aws_ecr_repository" "lambda_repository" {
  name                 = "lambda-cb-api-repository"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true

  tags = {
    Environment = "development"
  }
}

# AWS CLI login for ECR
resource "null_resource" "ecr_login" {
  provisioner "local-exec" {
    command = <<EOT
      aws ecr get-login-password --region ${var.aws_region} | \
      docker login --username AWS --password-stdin ${aws_ecr_repository.lambda_repository.repository_url}
    EOT
  }

  depends_on = [aws_ecr_repository.lambda_repository]
}

# Archive the Lambda code to detect changes
data "archive_file" "lambda_code" {
  type        = "zip"
  source_dir  = "${path.module}/resources/python/aws_lambda"
  output_path = "${path.module}/lambda_code.zip"
}

# Build and push Docker image when Lambda code changes
resource "null_resource" "docker_build_push" {
  triggers = {
    code_hash = data.archive_file.lambda_code.output_md5
  }

  provisioner "local-exec" {
    command = <<EOT
      REPO_URL=${aws_ecr_repository.lambda_repository.repository_url}
      HASH=${data.archive_file.lambda_code.output_md5}

      echo "Logging in to ECR at $REPO_URL..."
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin $REPO_URL

      echo "Building Docker image..."
      docker build -t aws_lambda:latest -f ${path.module}/resources/DockerFile ${path.module}/resources && docker tag aws_lambda:latest ${aws_ecr_repository.lambda_repository.repository_url}:latest

      echo "Tagging Docker image..."
      docker tag aws_lambda:latest $REPO_URL:$HASH
      docker tag aws_lambda:latest $REPO_URL:latest

      echo "Pushing Docker image..."
      docker push $REPO_URL:$HASH
      docker push $REPO_URL:latest
    EOT
  }

  depends_on = [
    aws_ecr_repository.lambda_repository,
    null_resource.ecr_login
  ]
}

# AWS Lambda function configuration
resource "aws_lambda_function" "lambda_function" {
  function_name = "put-mv-dt-db-lambda"
  image_uri     = "${aws_ecr_repository.lambda_repository.repository_url}:${data.archive_file.lambda_code.output_md5}"
  role          = aws_iam_role.iam_dev_role_cb_api.arn
  package_type  = "Image"
  timeout       = var.lambda_timeout
  memory_size   = 500

  environment {
    variables = {
      stream_name = var.stream_name
      secret_key = var.secret_key
      api_key  = var.api_key
      database = var.database
      bucket   = var.bucket_name
      table    = var.table
      role     = aws_iam_role.iam_dev_role_cb_api.arn
    }
  }

  depends_on = [
    null_resource.docker_build_push
  ]
}



# sns topic for lambda alerts
resource "aws_sns_topic" "lambda_alerts" {
  name = "lambda-alerts"
}


# alerts if the lambda fails in any case
resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
  alarm_name          = "Lambda-Error-Alarm"
  alarm_description   = "Triggered when Lambda function reports errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_actions       = [aws_sns_topic.lambda_alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.lambda_function.function_name
  }
}
