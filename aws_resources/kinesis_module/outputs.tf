output "stream_name" {
    description = "Name of the Kinesis stream."
    value = aws_kinesis_stream.coinbase_stream.name
}

output "firehose_name"{
    description = "Name of the Kinesis Firehose delivery stream."
    value = aws_kinesis_firehose_delivery_stream.coinbase_firehose.name
}

output "kinesis_stream_arn"{
    description = "ARN of the Kinesis stream."
    value = aws_kinesis_stream.coinbase_stream.arn
}