output "database"{ 
    description = "Name of the Glue database."
    value = aws_glue_catalog_database.coinbase_db.name 
}

output "crawler"{
    description = "Name of the Glue crawler."
    value = aws_glue_crawler.coinbase_s3_crawler.name
}

output "crawler_role"{
    description = "ARN of the IAM role used by the Glue crawler."
    value = aws_iam_role.glue_role.arn
}

output "data_location"{
    description = "ARN of the S3 data location registered in Lake Formation."
    value = aws_lakeformation_resource.data_location.arn
}

output "database_catalog"{ 
    description = "ARN of the Glue Data Catalog database."
    value = aws_glue_catalog_database.coinbase_db.arn
}