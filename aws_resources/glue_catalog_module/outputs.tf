output "database"{ 
    value = aws_glue_catalog_database.coinbase_db.name 
}

output "crawler"{
    value = aws_glue_crawler.coinbase_s3_crawler.name
}

output "crawler_role"{
    value = aws_iam_role.glue_role.arn
}

output "data_location"{
    value = aws_lakeformation_resource.data_location.arn
}

output "database_catalog"{ 
    value = aws_glue_catalog_database.coinbase_db.arn
}