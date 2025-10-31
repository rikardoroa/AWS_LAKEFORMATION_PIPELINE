# variable "kms_key_arn"{
#     type = string
# }

# variable "bucket_arn"{
#     type = string
# }

# variable "lambda_role" {
#     type = string
# }


variable "kms_key_arn"{
    type = string
}

variable "bucket_arn"{
    type = string
}

variable "lambda_role" {
    type = string
}

variable "lambda_role_policy" {
    type = string
    description = "Lambda role policy name for dependency"
}