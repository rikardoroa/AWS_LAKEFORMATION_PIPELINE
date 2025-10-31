# # Kinesis stream
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

# resource "aws_kinesis_firehose_delivery_stream" "coinbase_firehose" {
#   name        = "coinbase-firehose"
#   destination = "extended_s3"

#   extended_s3_configuration {
#     role_arn           = var.lambda_role
#     bucket_arn         = var.bucket_arn
#     kms_key_arn        = var.kms_key_arn
    
#     # Prefix with dynamic partitioning - uses special placeholders
#     # !{partitionKeyFromQuery:xxx} 
#     prefix = "coinbase/ingest/base=!{partitionKeyFromQuery:base}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
#     error_output_prefix = "coinbase/errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/!{firehose:error-output-type}/"
    
#     buffering_size     = 64      # MB
#     buffering_interval = 300     # seconds
    
#     compression_format = "GZIP"
    
#     # Enable dynamic partitioning
#     dynamic_partitioning_configuration {
#       enabled = true
#     }
    
#     # Processing configuration to extract fields from JSON
#     processing_configuration {
#       enabled = true

#       processors {
#         type = "MetadataExtraction"
        
#         parameters {
#           parameter_name  = "JsonParsingEngine"
#           parameter_value = "JQ-1.6"
#         }
        
#         parameters {
#           parameter_name  = "MetadataExtractionQuery"
#           # Extracts the 'base' field from JSON for partitioning
#           parameter_value = "{base:.base}"
#         }
#       }
      
#       processors {
#         type = "AppendDelimiterToRecord"
        
#         parameters {
#           parameter_name  = "Delimiter"
#           parameter_value = "\\n"
#         }
#       }
#     }
#   }

#   kinesis_source_configuration {
#     kinesis_stream_arn = aws_kinesis_stream.coinbase_stream.arn
#     role_arn           = var.lambda_role
#   }
# }

# --- Kinesis Stream configuration ---
resource "aws_kinesis_stream" "coinbase_stream" {
  name             = "coinbase-price-stream"
  shard_count      = 1
  retention_period = 24
  encryption_type  = "KMS"
  kms_key_id       = var.kms_key_arn

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
}

# --- Dedicated IAM Role for Firehose ---
resource "aws_iam_role" "firehose_role" {
  name = "iam_firehose_from_kinesis_to_s3"

  # Trust policy: allows Firehose to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "firehose.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# --- IAM Policy: permissions for Firehose ---
resource "aws_iam_role_policy" "firehose_policy" {
  name = "firehose_access_policy"
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Allow reading from Kinesis stream
      {
        Sid: "KinesisRead",
        Effect: "Allow",
        Action: [
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ],
        Resource: [aws_kinesis_stream.coinbase_stream.arn, var.lambda_arn]
      },
      # Allow writing to S3 bucket
      {
        Sid: "S3Write",
        Effect: "Allow",
        Action: [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ],
        Resource: [
          var.bucket_arn,
          "${var.bucket_arn}/*"
        ]
      },
      # Allow writing logs to CloudWatch
      {
        Sid: "Logs",
        Effect: "Allow",
        Action: ["logs:PutLogEvents"],
        Resource: "*"
      },
      # Allow encrypt/decrypt using KMS key
      {
        Sid: "KMSEncryption",
        Effect: "Allow",
        Action: [
          "kms:Encrypt","kms:Decrypt","kms:ReEncrypt*",
          "kms:GenerateDataKey*","kms:DescribeKey"
        ],
        Resource: var.kms_key_arn
      }
    ]
  })
}

# --- Kinesis Firehose Delivery Stream ---
resource "aws_kinesis_firehose_delivery_stream" "coinbase_firehose" {
  name        = var.firehose_name
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = var.bucket_arn
    compression_format = "GZIP"
    kms_key_arn        = var.kms_key_arn

    # Firehose requires error_output_prefix if prefix uses dynamic expressions
    prefix              = "raw/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"

    buffering_interval = 60
    buffering_size     = 64

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/${var.firehose_name}"
      log_stream_name = "S3Delivery"
    }
  }

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.coinbase_stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }
}
