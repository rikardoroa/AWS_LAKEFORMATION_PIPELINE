output  "scheduler_name"{
    description = "Name of the EventBridge Scheduler."
    value = aws_scheduler_schedule.lambda_api_coinbase_scheduler.name
}

output  "scheduler_arn"{
    description = "ARN of the EventBridge Scheduler."
    value = aws_scheduler_schedule.lambda_api_coinbase_scheduler.arn
}