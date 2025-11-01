variable "lambda_timeout" {
  description = "Timeout for the Lambda function in seconds."
  type        = number
  default     = 360 # 6 minutes
}

variable "aws_region" {
  description = "AWS region used for deployment."
  type        = string
  default     = "us-east-2"
}

variable "bucket_arn" {
  description = "ARN of the S3 bucket used for data storage."
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for encryption."
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket used for data."
  type        = string
}

variable "database" {
  description = "Name of the Glue/Athena database."
  type        = string
}

variable "table" {
  description = "Name of the Athena table used for querying."
  type        = string
  default     = "coinbase_currency_prices"
}

variable "api_key" {
  description = "Coinbase API key value."
  type        = string
}

variable "stream_name" {
  description = "Name of the Kinesis data stream."
  type        = string
}

variable "secret_key" {
  description = "Coinbase API secret key."
  type        = string
}

variable "crawler_role" {
  description = "ARN of the IAM role used by the Glue crawler."
  type        = string
}

variable "data_location" {
  description = "ARN of the Lake Formation data location."
  type        = string
}

variable "terraform_bucket" {
  description = "S3 bucket for Terraform remote state."
  type        = string
  default     = "terraform-api-data-coinbase"
}
