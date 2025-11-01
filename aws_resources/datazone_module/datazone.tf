##########################################
# 📌 Data & Identity
##########################################
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

##########################################
# 🧩 IAM Role – Domain Execution (Fixed trust)
##########################################
resource "aws_iam_role" "datazone_domain_execution_role" {
  name = "iam_datazone_domain_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowDataZoneAssume",
        Effect = "Allow",
        Principal = {
          Service = "datazone.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      },
      {
        Sid    = "AllowDataZoneTagAndContext",
        Effect = "Allow",
        Principal = {
          Service = "datazone.amazonaws.com"
        },
        Action = [
          "sts:AssumeRole",
          "sts:TagSession",
          "sts:SetContext"
        ]
      }
    ]
  })
}

##########################################
# 🧩 IAM Policy – Domain Execution
##########################################
resource "aws_iam_policy" "datazone_domain_execution_policy" {
  name        = "datazone_domain_execution_policy"
  description = "Allow DataZone to integrate with Glue, LakeFormation, S3 and KMS for Coinbase data"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid: "DataZoneCoreAccess",
        Effect: "Allow",
        Action: [
          # 🔹 DataZone & Governance
          "datazone:*",

          # 🔹 Glue Catalog
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartitions",
          "glue:GetCatalogImportStatus",

          # 🔹 Lake Formation
          "lakeformation:GetDataAccess",
          "lakeformation:GetEffectivePermissionsForPath",
          "lakeformation:ListResources",

          # 🔹 S3 lectura básica
          "s3:GetObject",
          "s3:ListBucket",

          # 🔹 KMS decrypt
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey*"
        ],
        Resource: [
          "*",
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*",
          var.kms_key_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "datazone_domain_execution_attach" {
  role       = aws_iam_role.datazone_domain_execution_role.name
  policy_arn = aws_iam_policy.datazone_domain_execution_policy.arn
}

##########################################
# 🧩 IAM Role – Domain Service
##########################################
resource "aws_iam_role" "datazone_domain_service_role" {
  name = "iam_datazone_domain_service_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowDataZoneServiceAssume",
        Effect = "Allow",
        Principal = {
          Service = "datazone.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# 🔹 Reutilizamos la misma policy para el service role
resource "aws_iam_role_policy_attachment" "datazone_domain_service_attach" {
  role       = aws_iam_role.datazone_domain_service_role.name
  policy_arn = aws_iam_policy.datazone_domain_execution_policy.arn
}

##########################################
# 🏗️ DataZone Domain (compatible version)
##########################################
resource "aws_datazone_domain" "coinbase_domain" {
  name                  = "coinbase-data-domain"
  description           = "AWS DataZone domain for Coinbase LakeFormation pipeline"
  domain_execution_role = aws_iam_role.datazone_domain_execution_role.arn
  kms_key_identifier    = var.kms_key_arn

  tags = {
    Project = "AWS_LAKEFORMATION_PIPELINE"
    Owner   = "Ricardo Roa"
  }
}

##########################################
# 👥 DataZone Project (opcional)
##########################################
resource "aws_datazone_project" "analytics_team" {
  domain_identifier = aws_datazone_domain.coinbase_domain.id
  name              = "analytics-project"
  description       = "BI & analytics team project for Coinbase Lake data"
}

##########################################
# 💡 Outputs
##########################################
output "datazone_domain_id" {
  value = aws_datazone_domain.coinbase_domain.id
}

output "datazone_project_id" {
  value = aws_datazone_project.analytics_team.id
}