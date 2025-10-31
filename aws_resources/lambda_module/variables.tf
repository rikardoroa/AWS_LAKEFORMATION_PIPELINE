variable "lambda_timeout" {
  description = "The timeout for the Lambda function in seconds"
  type        = number
  default     = 360 # 6 minutes
}

variable "aws_region" {
  description = "aws region"
  type        = string
  default     = "us-east-2"
}

variable "bucket_arn" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "database"{
  type = string
}

# variable "crawler"{
#   type = string
# }

variable "table"{
  description = "athena table"
  type = string
  default     = "coinbase_currency_prices"
}

variable "api_key" {
  type = string
}

variable "stream_name"{
  type = string
}

variable "secret_key"{
  type = string
}

variable "crawler_role"{
  type = string
}

# variable "firehose_name"{
#   type = string
# }

# variable "scheduler_name"{
#   type = string
# }

# variable "kinesis_stream_arn"{
#   type = string
# }

# variable "scheduler_arn"{
#   type = string
# }