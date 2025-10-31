# --- 1. S3 Bucket and KMS ---
module "bucket_utils" {
  source = "./bucket_module"
}

# --- 2. Kinesis Stream and Firehose ---
module "kinesis_utils" {
  source      = "./kinesis_module"
  bucket_arn  = module.bucket_utils.bucket_arn
  kms_key_arn = module.bucket_utils.kms_key_arn
}

# --- 3. Lambda (only depends on bucket and kinesis) ---
module "lambda_utils" {
  source      = "./lambda_module"
  bucket_name = module.bucket_utils.bucket_name
  bucket_arn  = module.bucket_utils.bucket_arn
  kms_key_arn = module.bucket_utils.kms_key_arn
  stream_name = module.kinesis_utils.stream_name
  api_key     = var.api_key
  secret_key  = var.secret_key
  database    = module.glue_catalog_utils.database
  crawler_role = module.glue_catalog_utils.crawler_role
  data_location = module.glue_catalog_utils.data_location

}

# --- 4. EventBridge Scheduler ---
module "eventbridge_utils" {
  source     = "./eventbridge_module"
  lambda_arn = module.lambda_utils.lambda_arn
}

# --- 5. Glue Catalog ---
module "glue_catalog_utils" {
  source      = "./glue_catalog_module"
  bucket_name = module.bucket_utils.bucket_name
  lambda_role = module.lambda_utils.lambda_role

}
