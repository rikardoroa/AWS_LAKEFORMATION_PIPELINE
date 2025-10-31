output "stream_name" {
    value = aws_kinesis_stream.coinbase_stream.name
}


output "firehose_name"{
    value = aws_kinesis_firehose_delivery_stream.coinbase_firehose.name
}

output "kinesis_stream_arn"{
    value = aws_kinesis_stream.coinbase_stream.arn
}