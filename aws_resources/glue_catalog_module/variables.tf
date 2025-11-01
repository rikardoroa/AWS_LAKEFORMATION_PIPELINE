variable "lambda_role" {
    description = "ARN of the IAM role used by the Lambda."
    type = string
}

variable "bucket_name"{
    description = "Name of the S3 bucket used for Firehose output."
    type = string
}

variable "kms_key_arn"{
    description = "ARN of the KMS key for encryption."
    type = string
}

variable "terraform_user"{
    description = "user for execute lakeformation permissions"
    type = string
    default = "arn:aws:iam::163257074638:user/rroatest"

}