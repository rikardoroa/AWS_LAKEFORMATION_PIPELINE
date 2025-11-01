# bucket module
module "bucket_utils" {
  source      = "./bucket_module"
  domain_execution_role_name   = module.datazone_utils.domain_execution_role_name
  domain_environment_role_name = module.datazone_utils.domain_environment_role_name
}

# kinesis module
module "kinesis_utils" {
  source      = "./kinesis_module"
  bucket_arn  = module.bucket_utils.bucket_arn
  kms_key_arn = module.bucket_utils.kms_key_arn
}

# lambda module
module "lambda_utils" {
  source        = "./lambda_module"
  bucket_name   = module.bucket_utils.bucket_name
  bucket_arn    = module.bucket_utils.bucket_arn
  kms_key_arn   = module.bucket_utils.kms_key_arn
  stream_name   = module.kinesis_utils.stream_name
  api_key       = var.api_key
  secret_key    = var.secret_key
  database      = module.glue_catalog_utils.database
  crawler_role  = module.glue_catalog_utils.crawler_role
  data_location = module.glue_catalog_utils.data_location
}

# eventbridge module
module "eventbridge_utils" {
  source     = "./eventbridge_module"
  lambda_arn = module.lambda_utils.lambda_arn
}

# glue module
module "glue_catalog_utils" {
  source       =  "./glue_catalog_module"
  bucket_name  =  module.bucket_utils.bucket_name
  lambda_role  =  module.lambda_utils.lambda_role
  kms_key_arn  =  module.bucket_utils.kms_key_arn
  root_role    =  var.root_role
}

# datazone module
module "datazone_utils" {
  source           = "./datazone_module"
  database_catalog = module.glue_catalog_utils.database_catalog
  kms_key_arn      = module.bucket_utils.kms_key_arn
  bucket_name      = module.bucket_utils.bucket_name
}