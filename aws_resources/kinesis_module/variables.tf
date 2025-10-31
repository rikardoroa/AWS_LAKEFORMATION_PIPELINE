variable "kms_key_arn"{
    type = string
}

variable "bucket_arn"{
    type = string
}

variable "firehose_name" {
  type    = string
  default = "coinbase-firehose"
}

# variable "lambda_role" {
#     type = string
# }
