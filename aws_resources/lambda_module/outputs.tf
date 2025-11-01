output "lambda_arn"{
  description = "ARN of the Lambda function."
  value = aws_lambda_function.lambda_function.arn
}

output "lambda_role"{
  description = "ARN of the IAM role used by the Lambda."
  value = aws_iam_role.iam_dev_role_cb_api.arn
}