# inner account id and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Lambda IAM Role
resource "aws_iam_role" "iam_dev_role_cb_api" {
  name = "iam_dev_role_cb_api"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "scheduler.amazonaws.com",
            "firehose.amazonaws.com"
          ]
        }
      }
    ]
  })
}

# Lambda Policy Document
data "aws_iam_policy_document" "pipeline_dev_policy_cb_api" {
  statement {
    sid    = "CloudWatchLogging"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutRetentionPolicy",
      "logs:DeleteLogGroup",
      "logs:DeleteLogStream"
    ]
    resources = ["arn:aws:logs:*:*:log-group:/aws/lambda/${aws_lambda_function.lambda_function.function_name}:*",
    "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/*"]
  }

  statement {
    sid    = "S3AndKMSAccess"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]
    resources = [var.bucket_arn,"${var.bucket_arn}/*"]
  }

   statement {
    sid    = "AllowEventBridgeInvokeLambda"
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [aws_lambda_function.lambda_function.arn]
  }

  statement {
    sid    = "KMSKeyPermissions"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [var.kms_key_arn]
  }



statement {
  sid    = "KinesisStreamAccess"
  effect = "Allow"
  actions = [
    "kinesis:DescribeStream",
    "kinesis:GetShardIterator",
    "kinesis:GetRecords",
    "kinesis:ListShards",
    "kinesis:PutRecord",
    "kinesis:PutRecords"
  ]
  resources = [
    "arn:aws:kinesis:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stream/${var.stream_name}"
  ]
}

}

# Attach Inline Policy to Role
resource "aws_iam_role_policy" "lambda_permissions" {
  name   = "lambda_logging_with_layer"
  role   = aws_iam_role.iam_dev_role_cb_api.name
  policy = data.aws_iam_policy_document.pipeline_dev_policy_cb_api.json
}
