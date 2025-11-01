#  role for the eventbrigde scheduler
resource "aws_iam_role" "scheduler_invoke_role" {
  name = "iam_eventbridge_scheduler_invoke_lambda"

  # Trust policy for scheduler assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { 
        Service = "scheduler.amazonaws.com" 
        },
      Action = "sts:AssumeRole"
    }]
  })
}

# policy that allows invoking the Lambda function
resource "aws_iam_role_policy" "scheduler_invoke_policy" {
  name = "eventbridge_scheduler_invoke_policy"
  role = aws_iam_role.scheduler_invoke_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["lambda:InvokeFunction"],
      Resource = var.lambda_arn
    }]
  })
}

# eventbrigde scheduler config
resource "aws_scheduler_schedule" "lambda_api_coinbase_scheduler" {
  name       = "lambda_api_coinbase_scheduler"
  group_name = "default"

  flexible_time_window { mode = "OFF" }
  schedule_expression = "rate(5 minutes)"

  target {
    arn      = var.lambda_arn
    role_arn = aws_iam_role.scheduler_invoke_role.arn
  }
}
