data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# 1️⃣ Crear el rol de Glue
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

# 2️⃣ Política S3 para Glue
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

# 3️⃣ Política COMPLETA de Lake Formation para Glue
resource "aws_iam_role_policy" "glue_lakeformation_policy" {
  name = "glue_lakeformation_access"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "lakeformation:*"
        ],
        Resource = "*"
      }
    ]
  })
}

# 4️⃣ Configurar Data Lake Settings - INCLUYE LAMBDA ROLE
resource "aws_lakeformation_data_lake_settings" "default" {
  # Ambos roles son administradores
  admins = [
    aws_iam_role.glue_role.arn,
    var.lambda_role  # Lambda también debe ser admin
  ]
  
  depends_on = [
    aws_iam_role.glue_role,
    aws_iam_role_policy.glue_lakeformation_policy
  ]
}

# 5️⃣ Recurso de espera para propagación
resource "time_sleep" "wait_for_lakeformation_settings" {
  create_duration = "30s"

  depends_on = [
    aws_lakeformation_data_lake_settings.default
  ]
}

# 6️⃣ Crear la base de datos
resource "aws_glue_catalog_database" "coinbase_db" {
  name = "coinbase_api_s3_data"
  
  depends_on = [
    time_sleep.wait_for_lakeformation_settings
  ]
}

# 7️⃣ Registrar Data Location
resource "aws_lakeformation_resource" "data_location" {
  arn      = "arn:aws:s3:::${var.bucket_name}"
  role_arn = aws_iam_role.glue_role.arn
  
  depends_on = [
    time_sleep.wait_for_lakeformation_settings
  ]
}

# 8️⃣ Otorgar permisos a Lambda sobre TODAS las tablas (wildcard)
resource "aws_lakeformation_permissions" "lambda_all_tables" {
  principal   = var.lambda_role
  permissions = ["SELECT", "DESCRIBE", "ALTER"]

  table {
    database_name = aws_glue_catalog_database.coinbase_db.name
    wildcard      = true  # Permisos sobre TODAS las tablas
  }

  depends_on = [
    aws_glue_catalog_database.coinbase_db
  ]
}

# 9️⃣ JSON classifier
resource "aws_glue_classifier" "json_classifier" {
  name = "coinbase_json_classifier"

  json_classifier {
    json_path = "$"
  }
}

# 🔟 Glue crawler - SIN PREFIJO Y CON NOMBRE ESPECÍFICO
resource "aws_glue_crawler" "coinbase_s3_crawler" {
  name          = "coinbase_s3_crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.coinbase_db.name
  description   = "Crawler que detecta archivos JSON GZIP particionados"

  table_prefix = ""  # Sin prefijo para que cree la tabla exacta

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
    Grouping = { 
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    CrawlerOutput = {
      Tables = { 
        AddOrUpdateBehavior = "MergeNewColumns",
        TableName = "coinbase_currency_prices"  # Nombre específico
      }
    }
  })

  schedule = "cron(0/6 * * * ? *)"
  
  depends_on = [
    aws_glue_catalog_database.coinbase_db,
    aws_iam_role_policy.glue_s3_policy,
    aws_iam_role_policy.glue_lakeformation_policy,
    aws_lakeformation_permissions.lambda_all_tables
  ]
}

# 1️⃣1️⃣ Logs policy
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

# 1️⃣2️⃣ Verificación del bucket S3
data "aws_s3_bucket" "main" {
  bucket = var.bucket_name
}