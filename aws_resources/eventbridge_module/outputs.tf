output  "scheduler_name"{
    value = aws_scheduler_schedule.lambda_api_coinbase_scheduler.name
}

output  "scheduler_arn"{
    value = aws_scheduler_schedule.lambda_api_coinbase_scheduler.arn
}
