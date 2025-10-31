# data "aws_caller_identity" "current" {}
# data "aws_region" "current" {}

# # --- Glue IAM Role ---
# resource "aws_iam_role" "glue_role" {
#   name = "iam_glue_crawler_role"

#   # Trust policy: allows Glue to assume this role
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Principal = { Service = "glue.amazonaws.com" },
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

# # --- IAM Policy for S3 access ---
# resource "aws_iam_role_policy" "glue_role_policy" {
#   name = "glue_crawler_access_policy"
#   role = aws_iam_role.glue_role.id

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Sid: "S3Access",
#       Effect: "Allow",
#       Action: ["s3:GetObject", "s3:ListBucket"],
#       Resource: [
#         "arn:aws:s3:::${var.bucket_name}",
#         "arn:aws:s3:::${var.bucket_name}/*"
#       ]
#     },
#       {
#         Sid: "CloudWatchLogs",
#         Effect: "Allow",
#         Action: [
#           "logs:CreateLogGroup",
#           "logs:CreateLogStream",
#           "logs:PutLogEvents",
#           "logs:DescribeLogGroups",
#           "logs:DescribeLogStreams"
#         ],
#         Resource: [
#           "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/*",
#           "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/*:log-stream:*"
#         ]
#       },
#        {
#         Sid: "GlueCatalogAccess",
#         Effect: "Allow",
#         Action: [
#           "glue:GetDatabase",
#           "glue:GetDatabases",
#           "glue:GetTable",
#           "glue:GetTables",
#           "glue:CreateTable",
#           "glue:UpdateTable"
#         ],
#         Resource: [
#           "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:catalog",
#           "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/${aws_glue_catalog_database.coinbase_db.name}",
#           "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${aws_glue_catalog_database.coinbase_db.name}/*"
#         ]
#       }
#     ]
#   })
# }

# # --- Glue Database and Crawler ---
# resource "aws_glue_catalog_database" "coinbase_db" {
#   name = "coinbase_api_s3_data"
# }

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
    arn = "arn:aws:s3:::${var.bucket_name}/coinbase/ingest/"
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
resource "aws_glue_crawler" "coinbase_s3_crawler" {
  name          = "coinbase_s3_crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.coinbase_db.name

  s3_target {
    path = "s3://${var.bucket_name}/coinbase/ingest/"
  }

  recrawl_policy { recrawl_behavior = "CRAWL_EVERYTHING" }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  schedule = "cron(0/6 * * * ? *)"
}
