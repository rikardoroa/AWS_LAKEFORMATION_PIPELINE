# lambda module
module "lambda_utils" {
  source  = "./lambda_module"
  bucket_arn  = module.bucket_utils.bucket_arn
  kms_key_arn = module.bucket_utils.kms_key_arn
  bucket_name = module.bucket_utils.bucket_name
  # database    = module.glue_catalog_utils.database
  stream_name = module.kinesis_utils.stream_name
  api_key     = var.api_key
  secret_key  = var.secret_key
  scheduler_name = module.eventbridge_utils.scheduler_name
  firehose_name = module.kinesis_utils.firehose_name
  kinesis_stream_arn = module.kinesis_utils.kinesis_stream_arn
  scheduler_arn = module.eventbridge_utils.scheduler_arn
}

# bucket module
module "bucket_utils" {
  source  = "./bucket_module"
}


# kinesis module
module "kinesis_utils" {
  source  = "./kinesis_module"
  kms_key_arn = module.bucket_utils.kms_key_arn
  lambda_role = module.lambda_utils.lambda_role
  bucket_arn =  module.bucket_utils.bucket_arn
}


# eventbrigde module
module "eventbridge_utils" {
  source  = "./eventbridge_module"
  lambda_arn  =  module.lambda_utils.lambda_arn
  lambda_role =  module.lambda_utils.lambda_role
}



