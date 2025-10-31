##########################################
# 📌 Identidad y Región
##########################################
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

##########################################
# 🔹 1️⃣ Kinesis Stream - Fuente de datos
##########################################
resource "aws_kinesis_stream" "coinbase_stream" {
  name             = "coinbase-price-stream"
  shard_count      = 1
  retention_period = 24

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  encryption_type = "KMS"
  kms_key_id      = var.kms_key_arn
}

##########################################
# 🔹 2️⃣ Rol IAM para Firehose
##########################################
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

##########################################
# 🔹 3️⃣ Política IAM para Firehose
##########################################
data "aws_iam_policy_document" "firehose_policy" {
  # Acceso a S3
  statement {
    sid     = "S3Access"
    effect  = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = [
      var.bucket_arn,
      "${var.bucket_arn}/*"
    ]
  }

  # Lectura del stream Kinesis
  statement {
    sid     = "KinesisRead"
    effect  = "Allow"
    actions = [
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:GetShardIterator",
      "kinesis:GetRecords",
      "kinesis:ListShards"
    ]
    resources = [
      "arn:aws:kinesis:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stream/coinbase-price-stream"
    ]
  }

  # Cifrado KMS
  statement {
    sid     = "KMSForS3"
    effect  = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [var.kms_key_arn]
  }

  # Logs en CloudWatch
  statement {
    sid     = "CloudWatchLogs"
    effect  = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/kinesisfirehose/${var.firehose_name}",
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/kinesisfirehose/${var.firehose_name}:log-stream:*"
    ]
  }
}

##########################################
# 🔹 4️⃣ Asociar Política al Rol
##########################################
resource "aws_iam_role_policy" "firehose_policy_attach" {
  name   = "firehose_to_s3_policy"
  role   = aws_iam_role.firehose_role.id
  policy = data.aws_iam_policy_document.firehose_policy.json
}

##########################################
# 🔹 5️⃣ Kinesis Firehose → S3 (Extended S3)
##########################################
# resource "aws_kinesis_firehose_delivery_stream" "coinbase_firehose" {
#   name        = var.firehose_name
#   destination = "extended_s3"

#   extended_s3_configuration {
#     role_arn           = aws_iam_role.firehose_role.arn
#     bucket_arn         = var.bucket_arn
#     compression_format = "UNCOMPRESSED"
#     kms_key_arn        = var.kms_key_arn

#     # 🔸 Coincide con la estructura esperada por el Crawler
#     prefix              = "coinbase/ingest/partition_date=!{timestamp:yyyy-MM-dd}/!{firehose:random-string}.json.gz" #"coinbase/ingest/partition_date=!{timestamp:yyyy-MM-dd}/"
#     error_output_prefix = "coinbase/errors/!{firehose:error-output-type}/"

#     buffering_interval = 60  # segundos
#     buffering_size     = 5   # MB
#     # 🔥 Nuevo parámetro
#     file_extension = ".json.gz"
#   }

#   kinesis_source_configuration {
#     kinesis_stream_arn = aws_kinesis_stream.coinbase_stream.arn
#     role_arn           = aws_iam_role.firehose_role.arn
#   }

# }

# resource "aws_kinesis_firehose_delivery_stream" "coinbase_firehose" {
#   name        = var.firehose_name
#   destination = "extended_s3"

#   extended_s3_configuration {
#     role_arn           = aws_iam_role.firehose_role.arn
#     bucket_arn         = var.bucket_arn
#     compression_format = "GZIP"
#     kms_key_arn        = var.kms_key_arn

#     # 🔸 Coincide con la estructura esperada por el Crawler
#     prefix = "coinbase/ingest/partition_date=!{timestamp:yyyy-MM-dd}/"
#     error_output_prefix = "coinbase/errors/!{firehose:error-output-type}/"

#     buffering_interval = 60  # segundos
#     buffering_size     = 5   # MB
#   }

#   kinesis_source_configuration {
#     kinesis_stream_arn = aws_kinesis_stream.coinbase_stream.arn
#     role_arn           = aws_iam_role.firehose_role.arn
#   }
# }

resource "aws_kinesis_firehose_delivery_stream" "coinbase_firehose" {
  name        = var.firehose_name
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = var.bucket_arn
    compression_format = "UNCOMPRESSED"
    kms_key_arn        = var.kms_key_arn

    # 📦 Estructura clara para el crawler
    # Cada archivo será un JSONL (.json)
    prefix              = "coinbase/ingest/partition_date=!{timestamp:yyyy-MM-dd}/"
    error_output_prefix = "coinbase/errors/!{firehose:error-output-type}/"

    buffering_interval  = 60   # segundos
    buffering_size      = 5    # MB

    # 🔸 Extensión opcional personalizada (requiere Terraform >= 1.9 y AWS provider >= 5.50)
    file_extension = ".json"
  }

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.coinbase_stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }
}