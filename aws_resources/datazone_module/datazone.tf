##########################################
# 📦 AWS DataZone Domain (espacio principal)
##########################################
resource "aws_datazone_domain" "main" {
  name        = "coinbase-data-domain"
  description = "DataZone domain for Coinbase LakeFormation data"
  kms_key_identifier = var.kms_key_arn
}

##########################################
# 👥 Proyecto DataZone (opcional)
##########################################
resource "aws_datazone_project" "analytics_team" {
  domain_identifier = aws_datazone_domain.main.id
  name              = "analytics-project"
  description       = "Project for BI and analytics team to access Coinbase data"
}

##########################################
# 📖 DataZone Catalog – publicación del Glue Catalog
##########################################
resource "aws_datazone_glue_catalog" "main" {
  domain_identifier = aws_datazone_domain.main.id
  name              = "coinbase-datazone-catalog"
  description       = "Catalog linked to Glue database coinbase_api_s3_data"
  glue_database_arn = var.database_catalog
}
