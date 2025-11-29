resource "aws_kinesis_firehose_delivery_stream" "clickstream_stream" {
  name        = "clickstream-delivery-stream-${random_id.suffix.hex}"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.raw_data.arn

    # Partitioning by date
    prefix = "year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"

    # Error handling
    error_output_prefix = "errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/!{firehose:error-output-type}/"

    # Buffering controls
    buffering_interval = 60 # deliver every 60 seconds
    buffering_size     = 5  # or when 5 MB of data is collected

    # Compress the data with GZIP before delivering to S3
    compression_format = "GZIP"
  }
}

output "firehose_delivery_stream_name" {
  description = "The name of the Kinesis Firehose delivery stream."
  value       = aws_kinesis_firehose_delivery_stream.clickstream_stream.name
}

