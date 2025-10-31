# Kinesis stream
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
    
    # Prefix with dynamic partitioning - uses special placeholders
    # !{partitionKeyFromQuery:xxx} or !{timestamp:xxx}
    prefix = "coinbase/ingest/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "coinbase/errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/!{firehose:error-output-type}/"
    
    buffering_size     = 1   
    buffering_interval = 60
    
    compression_format = "GZIP"
    
    # Enable dynamic partitioning
    dynamic_partitioning_configuration {
      enabled = true
    }
    
    # Processing configuration to extract fields from JSON
    processing_configuration {
      enabled = true

      processors {
        type = "MetadataExtraction"
        
        parameters {
          parameter_name  = "JsonParsingEngine"
          parameter_value = "JQ-1.6"
        }
        
        parameters {
          parameter_name  = "MetadataExtractionQuery"
          # Extracts the 'base' field from JSON for partitioning
          parameter_value = "{base:.base}"
        }
      }
      
      processors {
        type = "AppendDelimiterToRecord"
        
        parameters {
          parameter_name  = "Delimiter"
          parameter_value = "\\n"
        }
      }
    }
  }

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.coinbase_stream.arn
    role_arn           = var.lambda_role
  }
}