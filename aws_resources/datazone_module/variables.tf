variable "kms_key_arn"{
    description = "kms key ARN"
    type  = string
}

variable "database_catalog"{
    description = "Catalog ARN used for glue database"
    type = string
}

variable "bucket_name"{
    description = "Name of the S3 bucket"
    type = string
}
