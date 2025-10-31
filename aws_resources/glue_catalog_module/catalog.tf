# data "aws_caller_identity" "current" {}
# data "aws_region" "current" {}

# resource "aws_glue_catalog_database" "coinbase_db" {
#   name = "coinbase_api_s3_data"
# }

# resource "aws_iam_role" "glue_role" {
#   name = "iam_glue_crawler_role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Principal = { Service = "glue.amazonaws.com" },
#       Action    = "sts:AssumeRole"
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "glue_service_role_attach" {
#   role       = aws_iam_role.glue_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
# }

# # 🔐 Lake Formation Data Location registration
# resource "aws_lakeformation_resource" "data_location" {
#   arn      = "arn:aws:s3:::${var.bucket_name}/coinbase/ingest/"
#   role_arn = aws_iam_role.glue_role.arn
# }


# # 🔐 DATA_LOCATION_ACCESS permission
# resource "aws_lakeformation_permissions" "crawler_data_location_perm" {
#   principal   = aws_iam_role.glue_role.arn
#   permissions = ["DATA_LOCATION_ACCESS"]

#   data_location {
#     arn = aws_lakeformation_resource.data_location.arn
#   }

#   depends_on = [
#     aws_glue_catalog_database.coinbase_db,
#     aws_lakeformation_resource.data_location
#   ]
# }

# # 🔐 Database-level permissions
# resource "aws_lakeformation_permissions" "crawler_database_perm" {
#   principal   = aws_iam_role.glue_role.arn
#   permissions = ["CREATE_TABLE","ALTER","DROP","DESCRIBE"]

#   database {
#     name = aws_glue_catalog_database.coinbase_db.name
#   }

#   depends_on = [
#     aws_glue_catalog_database.coinbase_db,
#     aws_lakeformation_resource.data_location
#   ]
  
# }

# # 🔐 Catalog permission (NEW)
# resource "aws_lakeformation_permissions" "crawler_catalog_perm" {
#   principal         = aws_iam_role.glue_role.arn
#   permissions       = ["DESCRIBE"]
#   catalog_resource  = true

#   depends_on = [
#     aws_glue_catalog_database.coinbase_db,
#     aws_lakeformation_resource.data_location
#   ]
# }


# # 🔹 JSON classifier
# resource "aws_glue_classifier" "json_classifier" {
#   name = "coinbase_json_classifier"

#   json_classifier {
#     json_path = "$"
#   }
# }

# # 🔹 Glue crawler
# resource "aws_glue_crawler" "coinbase_s3_crawler" {
#   name          = "coinbase_s3_crawler"
#   role          = aws_iam_role.glue_role.arn
#   database_name = aws_glue_catalog_database.coinbase_db.name
#   description   = "Crawler que detecta archivos JSON GZIP particionados en base/year/month/day/hour"

#   table_prefix = "coinbase_"

#   s3_target {
#     path = "s3://${var.bucket_name}/coinbase/ingest/"
#   }

#   classifiers = [aws_glue_classifier.json_classifier.name]

#   recrawl_policy {
#     recrawl_behavior = "CRAWL_EVERYTHING"
#   }

#   schema_change_policy {
#     update_behavior = "UPDATE_IN_DATABASE"
#     delete_behavior = "LOG"
#   }

#   configuration = jsonencode({
#     Version  = 1.0
#     Grouping = { TableGroupingPolicy = "CombineCompatibleSchemas" }
#   })

#   schedule = "cron(0/6 * * * ? *)"
# }



# # logs for glue role
# data "aws_iam_policy_document" "glue_logs_extra" {
#   statement {
#     effect = "Allow"
#     actions = [
#       "logs:CreateLogGroup",
#       "logs:CreateLogStream",
#       "logs:PutLogEvents",
#       "logs:DescribeLogStreams"
#     ]
#     resources = ["*"]
#   }
# }

# resource "aws_iam_policy" "glue_logs_extra" {
#   name   = "glue_logs_extra"
#   policy = data.aws_iam_policy_document.glue_logs_extra.json
# }

# resource "aws_iam_role_policy_attachment" "glue_logs_attach" {
#   role       = aws_iam_role.glue_role.name
#   policy_arn = aws_iam_policy.glue_logs_extra.arn
# }


# data "aws_caller_identity" "current" {}
# data "aws_region" "current" {}

# # 🔥 CRÍTICO: Configurar Data Lake Administrator PRIMERO
# resource "aws_lakeformation_data_lake_settings" "default" {
#   admins = [aws_iam_role.glue_role.arn]
# }

# resource "aws_glue_catalog_database" "coinbase_db" {
#   name = "coinbase_api_s3_data"
  
#   depends_on = [
#     aws_lakeformation_data_lake_settings.default
#   ]
# }

# resource "aws_iam_role" "glue_role" {
#   name = "iam_glue_crawler_role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Principal = { Service = "glue.amazonaws.com" },
#       Action    = "sts:AssumeRole"
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "glue_service_role_attach" {
#   role       = aws_iam_role.glue_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
# }

# # Agregar política para S3
# resource "aws_iam_role_policy" "glue_s3_policy" {
#   name = "glue_s3_access"
#   role = aws_iam_role.glue_role.id

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "s3:GetObject",
#           "s3:PutObject",
#           "s3:ListBucket"
#         ],
#         Resource = [
#           "arn:aws:s3:::${var.bucket_name}",
#           "arn:aws:s3:::${var.bucket_name}/*"
#         ]
#       }
#     ]
#   })
# }

# # 🔐 Lake Formation Data Location registration
# resource "aws_lakeformation_resource" "data_location" {
#   arn      = "arn:aws:s3:::${var.bucket_name}/coinbase/ingest/"
#   role_arn = aws_iam_role.glue_role.arn
  
#   depends_on = [
#     aws_lakeformation_data_lake_settings.default,
#     aws_iam_role.glue_role
#   ]
# }

# # 🔐 DATA_LOCATION_ACCESS permission
# resource "aws_lakeformation_permissions" "crawler_data_location_perm" {
#   principal   = aws_iam_role.glue_role.arn
#   permissions = ["DATA_LOCATION_ACCESS"]

#   data_location {
#     arn = aws_lakeformation_resource.data_location.arn
#   }

#   depends_on = [
#     aws_lakeformation_data_lake_settings.default,
#     aws_lakeformation_resource.data_location
#   ]
# }

# # 🔐 Database-level permissions
# resource "aws_lakeformation_permissions" "crawler_database_perm" {
#   principal   = aws_iam_role.glue_role.arn
#   permissions = ["CREATE_TABLE", "ALTER", "DROP", "DESCRIBE"]

#   database {
#     name = aws_glue_catalog_database.coinbase_db.name
#   }

#   depends_on = [
#     aws_lakeformation_data_lake_settings.default,
#     aws_glue_catalog_database.coinbase_db
#   ]
# }

# # 🔐 Catalog permission
# resource "aws_lakeformation_permissions" "crawler_catalog_perm" {
#   principal        = aws_iam_role.glue_role.arn
#   permissions      = ["CREATE_DATABASE", "CREATE_TABLE"]
#   catalog_resource = true

#   depends_on = [
#     aws_lakeformation_data_lake_settings.default
#   ]
# }

# # 🔹 JSON classifier
# resource "aws_glue_classifier" "json_classifier" {
#   name = "coinbase_json_classifier"

#   json_classifier {
#     json_path = "$"
#   }
# }

# # 🔹 Glue crawler
# resource "aws_glue_crawler" "coinbase_s3_crawler" {
#   name          = "coinbase_s3_crawler"
#   role          = aws_iam_role.glue_role.arn
#   database_name = aws_glue_catalog_database.coinbase_db.name
#   description   = "Crawler que detecta archivos JSON GZIP particionados"

#   table_prefix = "coinbase_"

#   s3_target {
#     path = "s3://${var.bucket_name}/coinbase/ingest/"
#   }

#   classifiers = [aws_glue_classifier.json_classifier.name]

#   recrawl_policy {
#     recrawl_behavior = "CRAWL_EVERYTHING"
#   }

#   schema_change_policy {
#     update_behavior = "UPDATE_IN_DATABASE"
#     delete_behavior = "LOG"
#   }

#   configuration = jsonencode({
#     Version  = 1.0
#     Grouping = { TableGroupingPolicy = "CombineCompatibleSchemas" }
#   })

#   schedule = "cron(0/6 * * * ? *)"
  
#   depends_on = [
#     aws_lakeformation_permissions.crawler_database_perm,
#     aws_lakeformation_permissions.crawler_data_location_perm
#   ]
# }

# # Logs policy
# data "aws_iam_policy_document" "glue_logs_extra" {
#   statement {
#     effect = "Allow"
#     actions = [
#       "logs:CreateLogGroup",
#       "logs:CreateLogStream",
#       "logs:PutLogEvents",
#       "logs:DescribeLogStreams"
#     ]
#     resources = ["*"]
#   }
# }

# resource "aws_iam_policy" "glue_logs_extra" {
#   name   = "glue_logs_extra"
#   policy = data.aws_iam_policy_document.glue_logs_extra.json
# }

# resource "aws_iam_role_policy_attachment" "glue_logs_attach" {
#   role       = aws_iam_role.glue_role.name
#   policy_arn = aws_iam_policy.glue_logs_extra.arn
# }



# data "aws_caller_identity" "current" {}
# data "aws_region" "current" {}

# # 🔥 ÚNICO Data Lake Settings - incluye AMBOS roles como admins
# resource "aws_lakeformation_data_lake_settings" "default" {
#   admins = [
#     aws_iam_role.glue_role.arn
#     # El rol de Lambda se agregará dinámicamente desde el módulo lambda
#   ]
  
#   # Evitar conflictos con permisos heredados
#   create_database_default_permissions {
#     permissions = []
#     principal {
#       data_lake_principal_identifier = "IAM_ALLOWED_PRINCIPALS"
#     }
#   }
  
#   create_table_default_permissions {
#     permissions = []
#     principal {
#       data_lake_principal_identifier = "IAM_ALLOWED_PRINCIPALS"
#     }
#   }
# }

# resource "aws_glue_catalog_database" "coinbase_db" {
#   name = "coinbase_api_s3_data"
  
#   depends_on = [
#     aws_lakeformation_data_lake_settings.default
#   ]
# }

# resource "aws_iam_role" "glue_role" {
#   name = "iam_glue_crawler_role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Principal = { Service = "glue.amazonaws.com" },
#       Action    = "sts:AssumeRole"
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "glue_service_role_attach" {
#   role       = aws_iam_role.glue_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
# }

# # Política para S3
# resource "aws_iam_role_policy" "glue_s3_policy" {
#   name = "glue_s3_access"
#   role = aws_iam_role.glue_role.id

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "s3:GetObject",
#           "s3:PutObject",
#           "s3:ListBucket"
#         ],
#         Resource = [
#           "arn:aws:s3:::${var.bucket_name}",
#           "arn:aws:s3:::${var.bucket_name}/*"
#         ]
#       }
#     ]
#   })
# }

# # 🔐 Lake Formation Data Location registration
# resource "aws_lakeformation_resource" "data_location" {
#   arn      = "arn:aws:s3:::${var.bucket_name}/coinbase/ingest/"
#   role_arn = aws_iam_role.glue_role.arn
  
#   depends_on = [
#     aws_lakeformation_data_lake_settings.default,
#     aws_iam_role.glue_role
#   ]
# }

# # 🔐 DATA_LOCATION_ACCESS permission
# resource "aws_lakeformation_permissions" "crawler_data_location_perm" {
#   principal   = aws_iam_role.glue_role.arn
#   permissions = ["DATA_LOCATION_ACCESS"]

#   data_location {
#     arn = aws_lakeformation_resource.data_location.arn
#   }

#   depends_on = [
#     aws_lakeformation_data_lake_settings.default,
#     aws_lakeformation_resource.data_location
#   ]
# }

# # 🔐 Database-level permissions
# resource "aws_lakeformation_permissions" "crawler_database_perm" {
#   principal   = aws_iam_role.glue_role.arn
#   permissions = ["CREATE_TABLE", "ALTER", "DROP", "DESCRIBE"]

#   database {
#     name = aws_glue_catalog_database.coinbase_db.name
#   }

#   depends_on = [
#     aws_lakeformation_data_lake_settings.default,
#     aws_glue_catalog_database.coinbase_db
#   ]
# }

# # 🔐 Catalog permission
# resource "aws_lakeformation_permissions" "crawler_catalog_perm" {
#   principal        = aws_iam_role.glue_role.arn
#   permissions      = ["CREATE_DATABASE", "CREATE_TABLE"]
#   catalog_resource = true

#   depends_on = [
#     aws_lakeformation_data_lake_settings.default
#   ]
# }

# # 🔹 JSON classifier
# resource "aws_glue_classifier" "json_classifier" {
#   name = "coinbase_json_classifier"

#   json_classifier {
#     json_path = "$"
#   }
# }

# # 🔹 Glue crawler
# resource "aws_glue_crawler" "coinbase_s3_crawler" {
#   name          = "coinbase_s3_crawler"
#   role          = aws_iam_role.glue_role.arn
#   database_name = aws_glue_catalog_database.coinbase_db.name
#   description   = "Crawler que detecta archivos JSON GZIP particionados"

#   table_prefix = "coinbase_"

#   s3_target {
#     path = "s3://${var.bucket_name}/coinbase/ingest/"
#   }

#   classifiers = [aws_glue_classifier.json_classifier.name]

#   recrawl_policy {
#     recrawl_behavior = "CRAWL_EVERYTHING"
#   }

#   schema_change_policy {
#     update_behavior = "UPDATE_IN_DATABASE"
#     delete_behavior = "LOG"
#   }

#   configuration = jsonencode({
#     Version  = 1.0
#     Grouping = { TableGroupingPolicy = "CombineCompatibleSchemas" }
#   })

#   schedule = "cron(0/6 * * * ? *)"
  
#   depends_on = [
#     aws_lakeformation_permissions.crawler_database_perm,
#     aws_lakeformation_permissions.crawler_data_location_perm
#   ]
# }

# # Logs policy
# data "aws_iam_policy_document" "glue_logs_extra" {
#   statement {
#     effect = "Allow"
#     actions = [
#       "logs:CreateLogGroup",
#       "logs:CreateLogStream",
#       "logs:PutLogEvents",
#       "logs:DescribeLogStreams"
#     ]
#     resources = ["*"]
#   }
# }

# resource "aws_iam_policy" "glue_logs_extra" {
#   name   = "glue_logs_extra"
#   policy = data.aws_iam_policy_document.glue_logs_extra.json
# }

# resource "aws_iam_role_policy_attachment" "glue_logs_attach" {
#   role       = aws_iam_role.glue_role.name
#   policy_arn = aws_iam_policy.glue_logs_extra.arn
# }


data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# 🔥 CRÍTICO: Configurar Data Lake Administrator PRIMERO
resource "aws_lakeformation_data_lake_settings" "default" {
  admins = [aws_iam_role.glue_role.arn]
  
  # Omitir create_database_default_permissions y create_table_default_permissions
  # para usar control explícito de Lake Formation
}

resource "aws_glue_catalog_database" "coinbase_db" {
  name = "coinbase_api_s3_data"
  
  depends_on = [
    aws_lakeformation_data_lake_settings.default
  ]
}

resource "aws_iam_role" "glue_role" {
  name = "iam_glue_crawler_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "glue.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service_role_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Agregar política para S3
resource "aws_iam_role_policy" "glue_s3_policy" {
  name = "glue_s3_access"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      }
    ]
  })
}

# 🔐 Lake Formation Data Location registration
resource "aws_lakeformation_resource" "data_location" {
  arn      = "arn:aws:s3:::${var.bucket_name}/coinbase/ingest/"
  role_arn = aws_iam_role.glue_role.arn
  
  depends_on = [
    aws_lakeformation_data_lake_settings.default,
    aws_iam_role.glue_role
  ]
}

# 🔐 DATA_LOCATION_ACCESS permission
resource "aws_lakeformation_permissions" "crawler_data_location_perm" {
  principal   = aws_iam_role.glue_role.arn
  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = aws_lakeformation_resource.data_location.arn
  }

  depends_on = [
    aws_lakeformation_data_lake_settings.default,
    aws_lakeformation_resource.data_location
  ]
}

# 🔐 Database-level permissions
resource "aws_lakeformation_permissions" "crawler_database_perm" {
  principal   = aws_iam_role.glue_role.arn
  permissions = ["CREATE_TABLE", "ALTER", "DROP", "DESCRIBE"]

  database {
    name = aws_glue_catalog_database.coinbase_db.name
  }

  depends_on = [
    aws_lakeformation_data_lake_settings.default,
    aws_glue_catalog_database.coinbase_db
  ]
}

# 🔐 Catalog permission
resource "aws_lakeformation_permissions" "crawler_catalog_perm" {
  principal        = aws_iam_role.glue_role.arn
  permissions      = ["CREATE_DATABASE", "CREATE_TABLE"]
  catalog_resource = true

  depends_on = [
    aws_lakeformation_data_lake_settings.default
  ]
}

# 🔹 JSON classifier
resource "aws_glue_classifier" "json_classifier" {
  name = "coinbase_json_classifier"

  json_classifier {
    json_path = "$"
  }
}

# 🔹 Glue crawler
resource "aws_glue_crawler" "coinbase_s3_crawler" {
  name          = "coinbase_s3_crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.coinbase_db.name
  description   = "Crawler que detecta archivos JSON GZIP particionados"

  table_prefix = "coinbase_"

  s3_target {
    path = "s3://${var.bucket_name}/coinbase/ingest/"
  }

  classifiers = [aws_glue_classifier.json_classifier.name]

  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  configuration = jsonencode({
    Version  = 1.0
    Grouping = { TableGroupingPolicy = "CombineCompatibleSchemas" }
  })

  schedule = "cron(0/6 * * * ? *)"
  
  depends_on = [
    aws_lakeformation_permissions.crawler_database_perm,
    aws_lakeformation_permissions.crawler_data_location_perm
  ]
}

# Logs policy
data "aws_iam_policy_document" "glue_logs_extra" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "glue_logs_extra" {
  name   = "glue_logs_extra"
  policy = data.aws_iam_policy_document.glue_logs_extra.json
}

resource "aws_iam_role_policy_attachment" "glue_logs_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.glue_logs_extra.arn
}