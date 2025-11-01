# current account identity
data "aws_caller_identity" "current" {}

# Creating the KMS key resource
resource "aws_kms_key" "dts_kms_key" {
  description              = "Key for encryption"
  enable_key_rotation      = true
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
}

# Activating KMS key policy
resource "aws_kms_key_policy" "bucket_kms_key" {
  key_id = aws_kms_key.dts_kms_key.id
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-default-1"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowDataZoneDomainExecutionRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/iam_datazone_domain_execution_role"
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowDataZoneEnvironmentRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/iam_datazone_environment_role"
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ]
        Resource = "*"
      }
    ]
  })
}

# Creating KMS key alias
resource "aws_kms_alias" "dts_kms_alias" {
  name          = "alias/cb-api-key"
  target_key_id = aws_kms_key.dts_kms_key.key_id
}

# Creating the S3 bucket
resource "aws_s3_bucket" "bucket_creation" {
  bucket        = var.curated_bucket
  force_destroy = true
}

# Setting bucket access
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket = aws_s3_bucket.bucket_creation.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# bucket for athena results
resource "aws_s3_bucket" "athena_results" {
  bucket = "coinbase-athena-api-results"
  force_destroy = true
}

# workgroup for query results
resource "aws_athena_workgroup" "coinbase_workgroup" {
  name = "coinbase_athena_workgroup"
  description = "Workgroup for coinbase s3 results"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/athena-results/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = aws_kms_key.dts_kms_key.arn
      }
    }
  }
}