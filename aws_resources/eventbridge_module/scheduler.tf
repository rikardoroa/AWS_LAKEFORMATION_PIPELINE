resource "aws_scheduler_schedule" "lambda_api_coinbase_scheduler" {
  name       = "lambda_api_coinbase_scheduler"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "rate(5 minutes)"

  target {
    arn      = var.lambda_arn
    role_arn = var.lambda_role
  }
}