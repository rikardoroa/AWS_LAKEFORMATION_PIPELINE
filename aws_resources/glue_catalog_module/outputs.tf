output "database"{ 
    value = aws_glue_catalog_database.coinbase_db.name 
}

output "crawler"{
    value = aws_glue_crawler.coinbase_s3_crawler.name
}