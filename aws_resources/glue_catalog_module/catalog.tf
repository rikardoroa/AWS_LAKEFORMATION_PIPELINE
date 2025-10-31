# resource "aws_glue_catalog_database" "coinbase_db" {
#   name = "coinbase_api_s3_data"
# }

# resource "aws_glue_crawler" "coinbase_s3_crawler" {
#   name          = "coinbase_s3_crawler"
#   role          = var.lambda_role
#   database_name = aws_glue_catalog_database.coinbase_db.name

#   s3_target {
#     path = "s3://${var.bucket_name}/"
#   }
   
#   recrawl_policy {
#     recrawl_behavior = "CRAWL_EVERYTHING"
#   }

#   schema_change_policy {
#     update_behavior = "UPDATE_IN_DATABASE"
#     delete_behavior = "LOG"
#   }


#   schedule = "cron(0/6 * * * ? *)"
# }

resource "aws_glue_catalog_database" "coinbase_db" {
  name = "coinbase_api_s3_data"
}

resource "aws_glue_crawler" "coinbase_s3_crawler" {
  name          = "coinbase_s3_crawler"
  role          = var.lambda_role
  database_name = aws_glue_catalog_database.coinbase_db.name

  # s3 path
  s3_target {
    path = "s3://${var.bucket_name}/coinbase/ingest/"
  }
   
  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  # cron every 10 minutes
  schedule = "cron(0/10 * * * ? *)"
  
  # partition validation
  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
    }
  })
}