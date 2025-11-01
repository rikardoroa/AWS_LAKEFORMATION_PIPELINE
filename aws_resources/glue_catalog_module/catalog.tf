
# current account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


#glue role for crawler
resource "aws_iam_role" "glue_role" {
  name = "iam_glue_crawler_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = [
            "glue.amazonaws.com",
            "lakeformation.amazonaws.com"
          ]
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# policy for role
resource "aws_iam_role_policy_attachment" "glue_service_role_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# s3 and glue policy
resource "aws_iam_role_policy" "glue_s3_policy" {
  name = "glue_s3_access"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid: "AllowListBucket",
        Effect: "Allow",
        Action: [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        Resource: "arn:aws:s3:::${var.bucket_name}"
      },
      {
        Sid: "AllowReadWriteObjects",
        Effect: "Allow",
        Action: [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion"
        ],
        Resource: [
          "arn:aws:s3:::${var.bucket_name}/coinbase/*",
          "arn:aws:s3:::${var.bucket_name}/coinbase/coinbase_currency_prices/*"
        ]
      },
      {
        Sid: "AllowFirehosePrefixes",
        Effect: "Allow",
        Action: [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource: [
          "arn:aws:s3:::${var.bucket_name}/coinbase/ingest/*",
          "arn:aws:s3:::${var.bucket_name}/coinbase/coinbase_currency_prices/*"
        ]
      },
      {
        Sid: "AllowKMSAccess",
        Effect: "Allow",
        Action: [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource: var.kms_key_arn
      }
    ]
  })
}


# lakeformation policy
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

#glue lambda settings
resource "aws_lakeformation_data_lake_settings" "default" {
  catalog_id = data.aws_caller_identity.current.account_id

  admins = [
    aws_iam_role.glue_role.arn,
    var.lambda_role,
    var.terraform_user
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

# wait for lakeformation the settings to complete for glue and and lambda
resource "time_sleep" "wait_for_lakeformation_settings" {
  create_duration = "30s"
  depends_on = [aws_lakeformation_data_lake_settings.default]
}

# database creation in glue ***
resource "aws_glue_catalog_database" "coinbase_db" {
  name        = "coinbase_api_s3_data"
  description = "Glue Catalog DB for Coinbase API data"
  parameters  = { classification = "json" }

  depends_on = [time_sleep.wait_for_lakeformation_settings]
}

# data location registration in lakeformation
resource "aws_lakeformation_resource" "data_location" {
  arn = "arn:aws:s3:::${var.bucket_name}/coinbase/coinbase_currency_prices/*"
  role_arn = aws_iam_role.glue_role.arn
  depends_on = [time_sleep.wait_for_lakeformation_settings]
}


#json classifier
resource "aws_glue_classifier" "json_classifier" {
  name = "coinbase_json_classifier"

  json_classifier {
    json_path = "$"
  }
}

# Glue crawler **
resource "aws_glue_crawler" "coinbase_s3_crawler" {
  name          = "coinbase_s3_crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.coinbase_db.name
  description   = "Crawler  detection for JSON compressed files"
  table_prefix  = ""

  s3_target {
    path =  "s3://${var.bucket_name}/coinbase/coinbase_currency_prices/"
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



#permissions , role and policy
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

#crawler permission for lakeformation
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

# database permissions for lakeformation
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

# lambda role permissions for lakeformation
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


# addional crawler permissions for the database related to lakeformation
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

# lakeformation lambda permissions for data location
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

# lambda permission for table
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