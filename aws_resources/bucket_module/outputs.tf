output "kms_key_arn"{
  value = aws_kms_key.dts_kms_key.arn
}

output "bucket_arn"{
  value = aws_s3_bucket.bucket_creation.arn
}

output "bucket_name"{
  value = aws_s3_bucket.bucket_creation.bucket
}