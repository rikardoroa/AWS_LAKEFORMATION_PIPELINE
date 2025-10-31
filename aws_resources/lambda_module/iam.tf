# # # inner account id and region
# # data "aws_caller_identity" "current" {}
# # data "aws_region" "current" {}

# # # Lambda IAM Role
# # resource "aws_iam_role" "iam_dev_role_cb_api" {
# #   name = "iam_dev_role_cb_api"

# #   assume_role_policy = jsonencode({
# #     Version = "2012-10-17"
# #     Statement = [
# #       {
# #         Effect = "Allow"
# #         Action = "sts:AssumeRole"
# #         Principal = {
# #           Service = [
# #             "lambda.amazonaws.com",
# #             "firehose.amazonaws.com",
# #             "scheduler.amazonaws.com",
# #             "glue.amazonaws.com"
# #           ]
# #         }
# #       }
# #     ]
# #   })
# # }

# # # Lambda Policy Document
# # data "aws_iam_policy_document" "pipeline_dev_policy_cb_api" {
# #   statement {
# #     sid    = "CloudWatchLogging"
# #     effect = "Allow"
# #     actions = [
# #       "logs:DescribeLogGroups",
# #       "logs:DescribeLogStreams",
# #       "logs:GetLogEvents",
# #       "logs:FilterLogEvents",
# #       "logs:CreateLogGroup",
# #       "logs:CreateLogStream",
# #       "logs:PutLogEvents",
# #       "logs:PutRetentionPolicy",
# #       "logs:DeleteLogGroup",
# #       "logs:DeleteLogStream"
# #     ]
# #     resources = [
# #       "arn:aws:logs:*:*:log-group:/aws/lambda/${aws_lambda_function.lambda_function.function_name}:*",
# #       "arn:aws:logs:*:*:log-group:/aws/kinesisfirehose/${var.firehose_name}:*",
# #       "arn:aws:logs:*:*:log-group:/aws/scheduler/${var.scheduler_name}:*"
# #     ]
# #   }
  
# #   statement {
# #     sid    = "S3K"
# #     effect = "Allow"
# #     actions = [
# #       "s3:AbortMultipartUpload",
# #       "s3:GetBucketLocation",
# #       "s3:GetObject",
# #       "s3:ListBucket",
# #       "s3:ListBucketMultipartUploads",
# #       "s3:PutObject",
# #       "s3:PutObjectAcl",
# #       "kms:Encrypt",
# #       "kms:Decrypt",
# #       "kms:ReEncrypt*",
# #       "kms:GenerateDataKey*",
# #       "kms:DescribeKey"
# #     ]
# #     resources = [
# #       "arn:aws:s3:::${var.bucket_name}",
# #       "arn:aws:s3:::${var.bucket_name}/*",
# #       var.kms_key_arn
# #     ]
# #   }

# #   # NUEVO: Permisos específicos para Kinesis
# #   statement {
# #     sid    = "KinesisAccess"
# #     effect = "Allow"
# #     actions = [
# #       "kinesis:DescribeStream",
# #       "kinesis:DescribeStreamSummary",
# #       "kinesis:GetRecords",
# #       "kinesis:GetShardIterator",
# #       "kinesis:ListShards",
# #       "kinesis:ListStreams",
# #       "kinesis:PutRecord",
# #       "kinesis:PutRecords"
# #     ]
# #     resources = [
# #       var.kinesis_stream_arn
# #     ]
# #   }

# #   statement {
# #     sid    = "GlueAccess"
# #     effect = "Allow"
# #     actions = [
# #       "glue:CreateDatabase",
# #       "glue:GetDatabase",
# #       "glue:GetDatabases",
# #       "glue:CreateTable",
# #       "glue:UpdateTable",
# #       "glue:GetTable",
# #       "glue:GetTables",
# #       "glue:DeleteTable",
# #       "glue:GetPartition",
# #       "glue:GetPartitions",
# #       "glue:BatchCreatePartition",
# #       "glue:BatchDeletePartition",
# #       "glue:BatchGetPartition",
# #       "glue:GetCrawler",
# #       "glue:GetCrawlers",
# #       "glue:StartCrawler",
# #       "glue:UpdateCrawler",
# #       "glue:UpdatePartition",
# #       "glue:CreateCrawler",
# #       "glue:GetCatalogImportStatus",
# #       "lakeformation:GetDataAccess",
# #       "lakeformation:GrantPermissions",
# #       "lakeformation:RevokePermissions",
# #       "lakeformation:ListPermissions",
# #       "lakeformation:GetEffectivePermissionsForPrincipal",
# #       "lakeformation:GetResourceLFTags",
# #       "lakeformation:ListLFTags",
# #       "lakeformation:GetLFTag",
# #       "lakeformation:SearchDatabasesByLFTags",
# #       "lakeformation:SearchTablesByLFTags"
# #     ]
# #     resources = [
# #       "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:catalog",
# #       "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/${var.database}",
# #       "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.database}/*",
# #       "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:crawler/${var.crawler}",
# #       "arn:aws:lakeformation:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:catalog:${data.aws_caller_identity.current.account_id}"
# #     ]
# #   }
# # }

# # # Attach Inline Policy to Role
# # resource "aws_iam_role_policy" "lambda_permissions" {
# #   name   = "lambda_logging_with_layer"
# #   role   = aws_iam_role.iam_dev_role_cb_api.name
# #   policy = data.aws_iam_policy_document.pipeline_dev_policy_cb_api.json
# # }

# # resource "aws_lambda_permission" "allow_scheduler_invoke" {
# #   statement_id  = "AllowEventBridgeInvokeLambda"
# #   action        = "lambda:InvokeFunction"
# #   function_name = aws_lambda_function.lambda_function.function_name
# #   principal     = "scheduler.amazonaws.com"
# #   source_arn    = var.scheduler_arn
# # }


# ##############################################
# # IAM ROLE & POLICY FOR LAMBDA (Coinbase API)
# ##############################################

# # Obtener cuenta y región actual
# data "aws_caller_identity" "current" {}
# data "aws_region" "current" {}

# # Lambda IAM Role
# resource "aws_iam_role" "iam_dev_role_cb_api" {
#   name = "iam_dev_role_cb_api"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = "sts:AssumeRole"
#         Principal = {
#           Service = [
#             "lambda.amazonaws.com",
#             "firehose.amazonaws.com",
#             "scheduler.amazonaws.com",
#             "glue.amazonaws.com"
#           ]
#         }
#       }
#     ]
#   })
# }

# #################################################
# # IAM POLICY DOCUMENT - Lambda Permissions
# #################################################

# data "aws_iam_policy_document" "pipeline_dev_policy_cb_api" {

#   ######################################
#   # 1. CloudWatch Logs (Scoped)
#   ######################################
#   statement {
#     sid    = "CloudWatchLogging"
#     effect = "Allow"
#     actions = [
#       "logs:DescribeLogGroups",
#       "logs:DescribeLogStreams",
#       "logs:GetLogEvents",
#       "logs:FilterLogEvents",
#       "logs:CreateLogGroup",
#       "logs:CreateLogStream",
#       "logs:PutLogEvents",
#       "logs:PutRetentionPolicy",
#       "logs:DeleteLogGroup"
#     ]
#     resources = [
#       "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.lambda_function.function_name}:*",
#       "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/kinesisfirehose/${var.firehose_name}:*",
#       "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/scheduler/${var.scheduler_name}:*"
#     ]
#   }

#   ######################################
#   # 2. S3 Permissions (Data Lake Storage)
#   ######################################
#   statement {
#     sid    = "S3AccessForDataLake"
#     effect = "Allow"
#     actions = [
#       "s3:ListBucket",
#       "s3:GetBucketLocation",
#       "s3:PutObject",
#       "s3:GetObject",
#       "s3:DeleteObject"
#     ]
#     resources = [
#       "arn:aws:s3:::${var.bucket_name}",
#       "arn:aws:s3:::${var.bucket_name}/*"
#     ]
#   }

#   ######################################
#   # 3. Kinesis Stream & Firehose Integration
#   ######################################
#   statement {
#     sid    = "KinesisFirehoseIntegration"
#     effect = "Allow"
#     actions = [
#       # Kinesis
#       "kinesis:DescribeStream",
#       "kinesis:GetShardIterator",
#       "kinesis:GetRecords",
#       "kinesis:ListShards",
#       # Firehose
#       "firehose:PutRecord",
#       "firehose:PutRecordBatch",
#       "firehose:DescribeDeliveryStream"
#     ]
#     resources = [
#       "arn:aws:kinesis:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stream/${var.stream_name}",
#       "arn:aws:firehose:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:deliverystream/${var.firehose_name}"
#     ]
#   }

#   ######################################
#   # 4. Glue Catalog & Lake Formation
#   ######################################
#   statement {
#     sid    = "GlueAndLakeFormation"
#     effect = "Allow"
#     actions = [
#       "glue:CreateDatabase",
#       "glue:DeleteDatabase",
#       "glue:GetDatabase",
#       "glue:GetDatabases",
#       "glue:CreateTable",
#       "glue:DeleteTable",
#       "glue:GetTable",
#       "glue:GetTables",
#       "glue:UpdateTable",
#       "glue:GetPartition",
#       "glue:GetPartitions",
#       "glue:BatchCreatePartition",
#       "glue:BatchDeletePartition",
#       "glue:BatchGetPartition",
#       "lakeformation:GrantPermissions",
#       "lakeformation:GetDataAccess",
#       "lakeformation:GetResourceLFTags",
#       "lakeformation:AddLFTagsToResource",
#       "lakeformation:ListPermissions",
#       "lakeformation:RevokePermissions"
#     ]
#     resources = [
#       "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:catalog",
#       "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/*",
#       "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/*/*",
#       "arn:aws:lakeformation:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:catalog"
#     ]
#   }

#   ######################################
#   # 5. KMS Access (Encryption for S3, Glue)
#   ######################################
#   statement {
#     sid    = "KMSAccess"
#     effect = "Allow"
#     actions = [
#       "kms:Encrypt",
#       "kms:Decrypt",
#       "kms:GenerateDataKey",
#       "kms:DescribeKey"
#     ]
#     resources = [var.kms_key_arn]
#   }

#   ######################################
#   # 6. EventBridge / Scheduler Invocation
#   ######################################
#   statement {
#     sid    = "AllowEventBridgeInvokeLambda"
#     effect = "Allow"
#     actions = [
#       "lambda:InvokeFunction"
#     ]
#     resources = ["*"]
#   }
# }

# #################################################
# # IAM ROLE POLICY ATTACHMENT
# #################################################

# resource "aws_iam_role_policy" "pipeline_dev_policy_cb_api" {
#   name   = "pipeline_dev_policy_cb_api"
#   role   = aws_iam_role.iam_dev_role_cb_api.id
#   policy = data.aws_iam_policy_document.pipeline_dev_policy_cb_api.json
# }

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
            "firehose.amazonaws.com",
            "scheduler.amazonaws.com",
            "glue.amazonaws.com"
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
    resources = [
      "arn:aws:logs:*:*:log-group:/aws/lambda/${aws_lambda_function.lambda_function.function_name}:*",
      "arn:aws:logs:*:*:log-group:/aws/kinesisfirehose/${var.firehose_name}:*",
      "arn:aws:logs:*:*:log-group:/aws/scheduler/${var.scheduler_name}:*"
    ]
  }
  
  statement {
    sid    = "S3K"
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [
      "arn:aws:s3:::${var.bucket_name}",
      "arn:aws:s3:::${var.bucket_name}/*",
      var.kms_key_arn
    ]
  }

  # NUEVO: Permisos específicos para Kinesis
  statement {
    sid    = "KinesisAccess"
    effect = "Allow"
    actions = [
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
      "kinesis:ListShards",
      "kinesis:ListStreams",
      "kinesis:PutRecord",
      "kinesis:PutRecords"
    ]
    resources = [
      var.kinesis_stream_arn
    ]
  }

  statement {
    sid    = "GlueAccess"
    effect = "Allow"
    actions = [
      "glue:CreateDatabase",
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:CreateTable",
      "glue:UpdateTable",
      "glue:GetTable",
      "glue:GetTables",
      "glue:DeleteTable",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:BatchCreatePartition",
      "glue:BatchDeletePartition",
      "glue:BatchGetPartition",
      "glue:GetCrawler",
      "glue:GetCrawlers",
      "glue:StartCrawler",
      "glue:UpdateCrawler",
      "glue:UpdatePartition",
      "glue:CreateCrawler",
      "glue:GetCatalogImportStatus",
      "lakeformation:GetDataAccess",
      "lakeformation:GrantPermissions",
      "lakeformation:RevokePermissions",
      "lakeformation:ListPermissions",
      "lakeformation:GetEffectivePermissionsForPrincipal",
      "lakeformation:GetResourceLFTags",
      "lakeformation:ListLFTags",
      "lakeformation:GetLFTag",
      "lakeformation:SearchDatabasesByLFTags",
      "lakeformation:SearchTablesByLFTags"
    ]
    resources = [
      "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:catalog",
      "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/${var.database}",
      "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.database}/*",
      "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:crawler/${var.crawler}",
      "arn:aws:lakeformation:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:catalog:${data.aws_caller_identity.current.account_id}"
    ]
  }
}

# Attach Inline Policy to Role
resource "aws_iam_role_policy" "lambda_permissions" {
  name   = "lambda_logging_with_layer"
  role   = aws_iam_role.iam_dev_role_cb_api.name
  policy = data.aws_iam_policy_document.pipeline_dev_policy_cb_api.json
}

resource "aws_lambda_permission" "allow_scheduler_invoke" {
  statement_id  = "AllowEventBridgeInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = var.scheduler_arn
}