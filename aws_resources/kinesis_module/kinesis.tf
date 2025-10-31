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

# resource "aws_kinesis_firehose_delivery_stream" "coinbase_firehose" {
#   name        = "coinbase-firehose"
#   destination = "extended_s3"

#   extended_s3_configuration {
#     role_arn           = var.lambda_role
#     bucket_arn         = var.bucket_arn
#     kms_key_arn        = var.kms_key_arn
#   }

#   kinesis_source_configuration {
#     kinesis_stream_arn = aws_kinesis_stream.coinbase_stream.arn
#     role_arn           = var.lambda_role
#   }
# }


resource "aws_kinesis_firehose_delivery_stream" "coinbase_firehose" {
  name        = "coinbase-firehose"
  destination = "s3"

  extended_s3_configuration {
    role_arn           = var.lambda_role
    bucket_arn         = var.bucket_arn
    kms_key_arn        = var.kms_key_arn
  }

  data_format_conversion_configuration {
    enabled = true

    input_format_configuration {
      deserializer {
        open_x_json_ser_de {}
      }
    }

    output_format_configuration {
      serializer {
        open_x_json_ser_de {}
      }
    }
  }

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.coinbase_stream.arn
    role_arn           = var.lambda_role
  }
}