data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_glue_catalog_database" "coinbase_db" {
  name = "coinbase_api_s3_data"
}

# Rol de Glue (Crawler)
resource "aws_iam_role" "glue_role" {
  name = "iam_glue_crawler_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "glue.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# Adjunta la política administrada estándar de Glue
resource "aws_iam_role_policy_attachment" "glue_service_role_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Permisos extra (CloudWatch Logs, S3 data, Glue Catalog) si no los tienes ya en inline policy
# ...

# 🔐 Lake Formation: registra la data location y otorga permisos al rol del crawler
resource "aws_lakeformation_resource" "data_location" {
  arn = "arn:aws:s3:::${var.bucket_name}"
  role_arn = aws_iam_role.glue_role.arn
}

# **Permiso de Data Location** a la ruta (LF controla acceso al S3 en el Data Lake)
resource "aws_lakeformation_permissions" "crawler_data_location_perm" {
  principal   = aws_iam_role.glue_role.arn
  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = aws_lakeformation_resource.data_location.arn
  }
}


# **Permisos sobre la Database** para que el crawler cree/actualice tablas
resource "aws_lakeformation_permissions" "crawler_database_perm" {
  principal  = aws_iam_role.glue_role.arn
  permissions = ["CREATE_TABLE","ALTER","DROP","DESCRIBE"]

  database {
    name = aws_glue_catalog_database.coinbase_db.name
  }
}

# Crawler (apunta al prefijo donde Firehose escribe)
# resource "aws_glue_crawler" "coinbase_s3_crawler" {
#   name          = "coinbase_s3_crawler"
#   role          = aws_iam_role.glue_role.arn
#   database_name = aws_glue_catalog_database.coinbase_db.name

#   s3_target {
#     path = "s3://${var.bucket_name}/coinbase/ingest/"
#   }

#   recrawl_policy { recrawl_behavior = "CRAWL_EVERYTHING" }

#   schema_change_policy {
#     update_behavior = "UPDATE_IN_DATABASE"
#     delete_behavior = "LOG"
#   }

#   schedule = "cron(0/6 * * * ? *)"
# }


resource "aws_glue_crawler" "coinbase_s3_crawler" {
  name          = "coinbase_s3_crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.coinbase_db.name

  # 🔍 Define clasificación explícita y recorre todas las particiones base/year/month/day/hour
  s3_target {
    path           = "s3://${var.bucket_name}/coinbase/ingest/"
    classification = "json"
    sample_size    = 10
  }

  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  schedule = "cron(0/6 * * * ? *)"
}