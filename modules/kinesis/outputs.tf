output "stream_arn" {
  description = "ARN of the pass Kinesis Data Stream."
  value       = aws_kinesis_stream.pass.arn
}

output "firehose_arn" {
  description = "ARN of the pass Kinesis Firehose delivery stream."
  value       = aws_kinesis_firehose_delivery_stream.pass.arn
}
