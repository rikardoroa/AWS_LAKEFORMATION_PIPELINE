# kinesis stream
resource "aws_kinesis_stream" "coinbase_stream" {
  name             = "coinbase-price-stream"
  shard_count      = 1                        
  retention_period = 24                        
  encryption_type  = "KMS"
  kms_key_id       = var.kms_key_arn

  stream_mode_details {
    stream_mode = "PROVISIONED"                
  }
}

resource "aws_kinesis_firehose_delivery_stream" "coinbase_firehose" {
  name        = "coinbase-firehose"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = var.lambda_role
    bucket_arn         = var.bucket_arn
    kms_key_arn        = var.kms_key_arn
    
    buffering_size     = 1   
    buffering_interval = 60
    file_extension = ".json"  
  }

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.coinbase_stream.arn
    role_arn           = var.lambda_role

  }
}