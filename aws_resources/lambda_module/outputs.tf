# output "lambda_arn"{
#   value = aws_lambda_function.lambda_function.arn
# }

# output "lambda_role"{
#   value = aws_iam_role.iam_dev_role_cb_api.arn
# }

output "lambda_arn"{
  value = aws_lambda_function.lambda_function.arn
}

output "lambda_role"{
  value = aws_iam_role.iam_dev_role_cb_api.arn
}

output "lambda_role_policy"{
  value = aws_iam_role_policy.lambda_permissions.id
}