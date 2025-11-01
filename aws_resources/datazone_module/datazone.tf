# account and region identity
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# iam for domain execution
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

# domain execution policy
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
          "datazone:*",
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartitions",
          "glue:GetCatalogImportStatus",
          "lakeformation:GetDataAccess",
          "lakeformation:GetEffectivePermissionsForPath",
          "lakeformation:ListResources",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource: [
          "*",
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      },
      {
        Sid    = "KMSFullForDataZoneDomainExecution",
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = var.kms_key_arn
      }
    ]
  })
}


# role and policy attached
resource "aws_iam_role_policy_attachment" "datazone_domain_execution_attach" {
  role       = aws_iam_role.datazone_domain_execution_role.name
  policy_arn = aws_iam_policy.datazone_domain_execution_policy.arn
}


# role for domain service
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

# attaching policy and role
resource "aws_iam_role_policy_attachment" "datazone_domain_service_attach" {
  role       = aws_iam_role.datazone_domain_service_role.name
  policy_arn = aws_iam_policy.datazone_domain_execution_policy.arn
}


# datazone domain definition
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

# project
resource "aws_datazone_project" "analytics_team" {
  domain_identifier = aws_datazone_domain.coinbase_domain.id
  name              = "analytics-project"
  description       = "BI & analytics team project for Coinbase Lake data"
}



#env role
resource "aws_iam_role" "datazone_environment_role" {
  name = "iam_datazone_environment_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = [
            "datazone.amazonaws.com",
            "glue.amazonaws.com",
            "lakeformation.amazonaws.com"
          ]
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "datazone_environment_policy" {
  name = "datazone_environment_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid: "GlueAndCatalog",
        Effect: "Allow",
        Action: [
          "glue:*",
          "lakeformation:*",
          "s3:*"
        ],
        Resource: "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "datazone_environment_attach" {
  role       = aws_iam_role.datazone_environment_role.name
  policy_arn = aws_iam_policy.datazone_environment_policy.arn
}





# blueprint
data "aws_datazone_environment_blueprint" "default_data_lake" {
  domain_id = aws_datazone_domain.coinbase_domain.id
  name      = "DefaultDataLake"
  managed   = true
}
# role for blueprint(env role)
resource "aws_datazone_environment_blueprint_configuration" "coinbase_blueprint" {
  domain_id                = aws_datazone_domain.coinbase_domain.id
  environment_blueprint_id = data.aws_datazone_environment_blueprint.default_data_lake.id
  enabled_regions          = ["us-east-2"]

  regional_parameters = {
    us-east-2 = {
      provisioning_role_arn = aws_iam_role.datazone_environment_role.arn
    }
  }
}