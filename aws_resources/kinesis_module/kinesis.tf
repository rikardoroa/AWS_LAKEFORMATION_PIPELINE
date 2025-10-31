

# # --- Kinesis Stream configuration ---
# resource "aws_kinesis_stream" "coinbase_stream" {
#   name             = "coinbase-price-stream"
#   shard_count      = 1
#   retention_period = 24
#   encryption_type  = "KMS"
#   kms_key_id       = var.kms_key_arn

#   stream_mode_details {
#     stream_mode = "PROVISIONED"
#   }
# }

# # --- Dedicated IAM Role for Firehose ---
# resource "aws_iam_role" "firehose_role" {
#   name = "iam_firehose_from_kinesis_to_s3"

#   # Trust policy: allows Firehose to assume this role
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Principal = { Service = "firehose.amazonaws.com" },
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

# # --- IAM Policy: permissions for Firehose ---
# resource "aws_iam_role_policy" "firehose_policy" {
#   name = "firehose_access_policy"
#   role = aws_iam_role.firehose_role.id

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       # Allow reading from Kinesis stream
#       {
#         Sid: "KinesisRead",
#         Effect: "Allow",
#         Action: [
#           "kinesis:DescribeStream",
#           "kinesis:DescribeStreamSummary",
#           "kinesis:GetShardIterator",
#           "kinesis:GetRecords",
#           "kinesis:ListShards"
#         ],
#         Resource: aws_kinesis_stream.coinbase_stream.arn
#       },
#       # Allow writing to S3 bucket
#       {
#         Sid: "S3Write",
#         Effect: "Allow",
#         Action: [
#           "s3:AbortMultipartUpload",
#           "s3:GetBucketLocation",
#           "s3:GetObject",
#           "s3:ListBucket",
#           "s3:ListBucketMultipartUploads",
#           "s3:PutObject",
#           "s3:PutObjectAcl"
#         ],
#         Resource: [
#           var.bucket_arn,
#           "${var.bucket_arn}/*"
#         ]
#       },
#       # Allow writing logs to CloudWatch
#       {
#         Sid: "Logs",
#         Effect: "Allow",
#         Action: ["logs:PutLogEvents"],
#         Resource: "*"
#       },
#       # Allow encrypt/decrypt using KMS key
#       {
#         Sid: "KMSEncryption",
#         Effect: "Allow",
#         Action: [
#           "kms:Encrypt","kms:Decrypt","kms:ReEncrypt*",
#           "kms:GenerateDataKey*","kms:DescribeKey"
#         ],
#         Resource: var.kms_key_arn
#       }
#     ]
#   })
# }

# # --- Kinesis Firehose Delivery Stream ---
# resource "aws_kinesis_firehose_delivery_stream" "coinbase_firehose" {
#   name        = var.firehose_name
#   destination = "extended_s3"

#   extended_s3_configuration {
#     role_arn           = aws_iam_role.firehose_role.arn
#     bucket_arn         = var.bucket_arn
#     compression_format = "GZIP"
#     kms_key_arn        = var.kms_key_arn

#     # Firehose requires error_output_prefix if prefix uses dynamic expressions
#     prefix              = "coinbase/ingest/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
#     error_output_prefix = "coinbase/ingest/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"

#     buffering_interval = 60
#     buffering_size     = 64

#     cloudwatch_logging_options {
#       enabled         = true
#       log_group_name  = "/aws/kinesisfirehose/${var.firehose_name}"
#       log_stream_name = "S3Delivery"
#     }
#   }

#   kinesis_source_configuration {
#     kinesis_stream_arn = aws_kinesis_stream.coinbase_stream.arn
#     role_arn           = aws_iam_role.firehose_role.arn
#   }
# }


data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Kinesis stream (descomenta si lo creará este módulo)
resource "aws_kinesis_stream" "coinbase_stream" {
  name             = "coinbase-price-stream"
  shard_count      = 1
  retention_period = 24
  stream_mode_details { stream_mode = "PROVISIONED" }
  encryption_type  = "KMS"
  kms_key_id       = var.kms_key_arn
}

# Rol dedicado para Firehose (asumido por firehose.amazonaws.com)
resource "aws_iam_role" "firehose_role" {
  name = "iam_firehose_from_kinesis_to_s3"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "firehose.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
}

data "aws_iam_policy_document" "firehose_policy" {
  statement {
    sid     = "S3Access"
    effect  = "Allow"
    actions = [
      "s3:AbortMultipartUpload","s3:GetBucketLocation","s3:GetObject",
      "s3:ListBucket","s3:ListBucketMultipartUploads","s3:PutObject","s3:PutObjectAcl"
    ]
    resources = [ var.bucket_arn, "${var.bucket_arn}/*" ]
  }

  statement {
    sid     = "KinesisRead"
    effect  = "Allow"
    actions = [
      "kinesis:DescribeStream","kinesis:DescribeStreamSummary","kinesis:GetShardIterator",
      "kinesis:GetRecords","kinesis:ListShards"
    ]
    resources = ["arn:aws:kinesis:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stream/coinbase-price-stream"]
  }

  # Si tu bucket usa KMS
  statement {
    sid     = "KMSForS3"
    effect  = "Allow"
    actions = ["kms:Encrypt","kms:Decrypt","kms:ReEncrypt*","kms:GenerateDataKey*","kms:DescribeKey"]
    resources = [ var.kms_key_arn ]
  }

  statement {
    sid     = "CloudWatchLogs"
    effect  = "Allow"
    actions = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents","logs:DescribeLogGroups","logs:DescribeLogStreams"]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/kinesisfirehose/${var.firehose_name}",
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/kinesisfirehose/${var.firehose_name}:log-stream:*"
    ]
  }
}

resource "aws_iam_role_policy" "firehose_policy_attach" {
  name   = "firehose_to_s3_policy"
  role   = aws_iam_role.firehose_role.id
  policy = data.aws_iam_policy_document.firehose_policy.json
}

resource "aws_kinesis_firehose_delivery_stream" "coinbase_firehose" {
  name        = var.firehose_name
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.coinbase_stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = var.bucket_arn
    compression_format = "GZIP"

   
    prefix              = "coinbase/ingest/date=!{partitionKeyFromQuery:date}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "coinbase/errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"

    buffering_interval = 60
    buffering_size     = 64

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/${var.firehose_name}"
      log_stream_name = "S3Delivery"
    }

    
    dynamic_partitioning_configuration {
      enabled = true
    }

    processing_configuration {
      enabled = true
      processors {
        type = "MetadataExtraction"
        parameters {
          parameter_name  = "MetadataExtractionQuery"
          parameter_value = "{date: .date}"
        }
        parameters {
          parameter_name  = "JsonParsingEngine"
          parameter_value = "JQ-1.6"
        }
      }
    }
  }
}
