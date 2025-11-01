output "kms_key_arn"{
  description = "KMS key ARN used for encryption"
  value = aws_kms_key.dts_kms_key.arn
}

output "bucket_arn"{
  description = "S3 bucket ARN for the Athena results"
  value = aws_s3_bucket.bucket_creation.arn
}

output "bucket_name"{
  description = "S3 bucket name for the Athena results"
  value = aws_s3_bucket.bucket_creation.bucket
}

output "athena_workgroup"{
  description = "Athena workgroup name used for query execution"
  value = aws_athena_workgroup.coinbase_workgroup.name
}
