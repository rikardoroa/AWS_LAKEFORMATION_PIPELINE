# --- Get current AWS account and region ---
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# --- IAM Role for Lambda function ---
resource "aws_iam_role" "iam_dev_role_cb_api" {
  name = "iam_dev_role_cb_api"

  # Trust policy: allows Lambda service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# --- IAM Policy for Lambda function ---
data "aws_iam_policy_document" "pipeline_dev_policy_cb_api" {
  # Allow CloudWatch Logs access
  statement {
    sid    = "CloudWatchLogging"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
    ]
  }

  # Allow access to S3 bucket (if Lambda writes output data)
  statement {
    sid    = "S3Access"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.bucket_name}",
      "arn:aws:s3:::${var.bucket_name}/*"
    ]
  }


  statement {
    sid    = "GlueCatalogAccess"
    effect = "Allow"
    actions = [
      "glue:GetTable",
      "glue:GetDatabase",
      "glue:CreateTable",
      "glue:UpdateTable"
    ]
    resources = [
      "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:catalog",
      "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/*",
      "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/*/*"
    ]
  }


  # Allow KMS encryption/decryption
  statement {
    sid    = "KMSAccess"
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
    sid    = "KinesisPutRecord"
    effect = "Allow"
    actions = [
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:ListShards",
      "kinesis:PutRecord",
      "kinesis:PutRecords"
    ]
    resources = [
      "arn:aws:kinesis:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stream/${var.stream_name}"
    ]
  }

  statement {
    sid    = "LakeFormationAccess"
    effect = "Allow"
    actions = [
      "lakeformation:ListPermissions",
      "lakeformation:GrantPermissions",
      "lakeformation:GetDataAccess",
      "lakeformation:GetEffectivePermissionsForPath"
    ]
    resources = ["*"]
  }
}

resource "aws_lakeformation_data_lake_settings" "data_lake_admins" {
  admins = [
    aws_iam_role.iam_dev_role_cb_api.arn
  ]
}


# --- Attach inline policy to Lambda role ---
resource "aws_iam_role_policy" "pipeline_dev_policy_attachment_cb_api" {
  name   = "pipeline_dev_policy_cb_api"
  role   = aws_iam_role.iam_dev_role_cb_api.id
  policy = data.aws_iam_policy_document.pipeline_dev_policy_cb_api.json
}

# --- Lake Formation: Database permissions
resource "aws_lakeformation_permissions" "lambda_db_permissions" {
  principal   = aws_iam_role.iam_dev_role_cb_api.arn
  permissions = ["CREATE_TABLE", "ALTER", "DESCRIBE"]

  database {
    name = var.database
  }
}

# --- Lake Formation: Register S3 path
resource "aws_lakeformation_resource" "coinbase_data_location" {
  arn      = "arn:aws:s3:::${var.bucket_name}"
  role_arn = aws_iam_role.iam_dev_role_cb_api.arn
}

# --- Lake Formation: Grant DATA_LOCATION_ACCESS on S3
resource "aws_lakeformation_permissions" "lambda_s3_data_access" {
  principal   = aws_iam_role.iam_dev_role_cb_api.arn
  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = aws_lakeformation_resource.coinbase_data_location.arn
  }
}

# --- Lake Formation: Grant DESCRIBE + SELECT on table
resource "aws_lakeformation_permissions" "lambda_table_access" {
  principal   = aws_iam_role.iam_dev_role_cb_api.arn
  permissions = ["DESCRIBE", "SELECT"]

  table {
    database_name = var.database
    name          = var.table
  }
}