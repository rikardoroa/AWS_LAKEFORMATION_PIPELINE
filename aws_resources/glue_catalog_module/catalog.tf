##########################################
# 📌 Data e Identidad
##########################################
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

##########################################
# 🧩 1️⃣ Crear el rol de Glue
##########################################
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

##########################################
# 🪣 2️⃣ Política S3 para Glue
##########################################
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
          "s3:ListBucket",
          "s3:DeleteObject"
        ],
        Resource = [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      }
    ]
  })
}

##########################################
# 🔐 3️⃣ Política de Lake Formation para Glue
##########################################
resource "aws_iam_role_policy" "glue_lakeformation_policy" {
  name = "glue_lakeformation_access"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["lakeformation:*"],
        Resource = "*"
      }
    ]
  })
}

##########################################
# 🧑‍💼 4️⃣ Data Lake Settings - Glue + Lambda admins
##########################################
resource "aws_lakeformation_data_lake_settings" "default" {
  catalog_id = data.aws_caller_identity.current.account_id

  admins = [
    aws_iam_role.glue_role.arn,
    var.lambda_role,
    "arn:aws:iam::163257074638:user/rroatest"
  ]

  create_database_default_permissions {
    permissions = ["ALL"]
    principal   = "IAM_ALLOWED_PRINCIPALS"
  }

  create_table_default_permissions {
    permissions = ["ALL"]
    principal   = "IAM_ALLOWED_PRINCIPALS"
  }

  depends_on = [
    aws_iam_role.glue_role,
    aws_iam_role_policy.glue_lakeformation_policy
  ]
}

##########################################
# ⏳ 5️⃣ Espera de propagación
##########################################
resource "time_sleep" "wait_for_lakeformation_settings" {
  create_duration = "30s"
  depends_on = [aws_lakeformation_data_lake_settings.default]
}

##########################################
# 🗂️ 6️⃣ Crear base de datos Glue Catalog
##########################################
resource "aws_glue_catalog_database" "coinbase_db" {
  name        = "coinbase_api_s3_data"
  description = "Glue Catalog DB for Coinbase API data"
  parameters  = { classification = "json" }

  depends_on = [time_sleep.wait_for_lakeformation_settings]
}

##########################################
# 📦 7️⃣ Registrar Data Location en Lake Formation
##########################################
resource "aws_lakeformation_resource" "data_location" {
  arn      = "arn:aws:s3:::${var.bucket_name}"
  role_arn = aws_iam_role.glue_role.arn
  depends_on = [time_sleep.wait_for_lakeformation_settings]
}


##########################################
# 🧩 Glue JSON Classifier
##########################################
resource "aws_glue_classifier" "json_classifier" {
  name = "coinbase_json_classifier"

  json_classifier {
    json_path = "$"
  }
}

##########################################
# 🧩 Glue Crawler para JSON GZIP
##########################################
resource "aws_glue_crawler" "coinbase_s3_crawler" {
  name          = "coinbase_s3_crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.coinbase_db.name
  description   = "Crawler que detecta archivos JSONL comprimidos con GZIP"
  table_prefix  = ""

  # 🔸 Apunta a los archivos que genera Firehose
  s3_target {
    path = "s3://${var.bucket_name}/coinbase/ingest/"
  }

  # 🔸 Usa el classifier JSON nativo
  classifiers = [aws_glue_classifier.json_classifier.name]

  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  configuration = jsonencode({
    Version  = 1.0,
    Grouping = { TableGroupingPolicy = "CombineCompatibleSchemas" }
  })

  schedule = "cron(0/10 * * * ? *)"

  depends_on = [
    aws_glue_catalog_database.coinbase_db,
    aws_iam_role_policy.glue_s3_policy,
    aws_iam_role_policy.glue_lakeformation_policy,
    aws_glue_classifier.json_classifier   
  ]
}


##########################################
# 📜 🔟 Permisos adicionales de Logs
##########################################
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

##########################################
# 🧩 1️⃣1️⃣ Permisos Lake Formation – CRAWLER
##########################################
resource "aws_lakeformation_permissions" "crawler_data_location_access" {
  catalog_id  = data.aws_caller_identity.current.account_id
  principal   = aws_iam_role.glue_role.arn
  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = aws_lakeformation_resource.data_location.arn
  }

  depends_on = [
    aws_lakeformation_resource.data_location,
    aws_lakeformation_data_lake_settings.default
  ]
}

resource "aws_lakeformation_permissions" "crawler_database_perms" {
  catalog_id  = data.aws_caller_identity.current.account_id
  principal   = aws_iam_role.glue_role.arn
  permissions = ["CREATE_TABLE", "ALTER", "DROP", "DESCRIBE"]

  database { name = aws_glue_catalog_database.coinbase_db.name }

  depends_on = [
    aws_glue_catalog_database.coinbase_db,
    aws_lakeformation_data_lake_settings.default
  ]
}


resource "aws_lakeformation_permissions" "lambda_glue_create" {
  catalog_id = data.aws_caller_identity.current.account_id
  principal  = var.lambda_role
  permissions = ["CREATE_TABLE"]

  database {name = aws_glue_catalog_database.coinbase_db.name}
  depends_on = [
    aws_glue_catalog_database.coinbase_db,
    aws_lakeformation_data_lake_settings.default
  ]
}



resource "aws_lakeformation_permissions" "crawler_tables_perms" {
  catalog_id  = data.aws_caller_identity.current.account_id
  principal   = aws_iam_role.glue_role.arn
  permissions = ["ALTER", "DROP", "DESCRIBE"]

  table {
    database_name = aws_glue_catalog_database.coinbase_db.name
    wildcard      = true
  }

  depends_on = [
    aws_glue_catalog_database.coinbase_db,
    aws_lakeformation_data_lake_settings.default
  ]
}

##########################################
# 🧩 1️⃣2️⃣ Permisos Lake Formation – LAMBDA
##########################################
resource "aws_lakeformation_permissions" "lambda_data_location_access" {
  catalog_id  = data.aws_caller_identity.current.account_id
  principal   = var.lambda_role
  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = aws_lakeformation_resource.data_location.arn
  }

  depends_on = [
    aws_lakeformation_resource.data_location,
    aws_lakeformation_data_lake_settings.default
  ]
}

resource "aws_lakeformation_permissions" "lambda_table_access" {
  catalog_id  = data.aws_caller_identity.current.account_id
  principal   = var.lambda_role
  permissions = ["DESCRIBE", "SELECT"]

  table {
    database_name = aws_glue_catalog_database.coinbase_db.name
    wildcard      = true
  }

  depends_on = [
    aws_glue_catalog_database.coinbase_db,
    aws_lakeformation_permissions.lambda_data_location_access
  ]
}

# ##########################################
# # 🧾 1️⃣3️⃣ Verificación del bucket
# ##########################################
# data "aws_s3_bucket" "main" {
#   bucket = var.bucket_name
# }
