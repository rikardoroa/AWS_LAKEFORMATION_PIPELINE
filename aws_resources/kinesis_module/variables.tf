variable "kms_key_arn"{
  description = "ARN of the KMS key for encryption."
  type = string
}

variable "bucket_arn"{
  description = "ARN of the target S3 bucket."
  type = string
}

variable "firehose_name" {
  description = "Name of the Kinesis Firehose delivery stream."
  type    = string
  default = "coinbase-firehose"
}