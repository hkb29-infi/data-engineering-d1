# This data source zips the 'src' directory containing our Lambda handler.
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/../transformer-only.zip" # Creates a zip of only the transformer script
}

# Upload the zipped Lambda code to S3
resource "aws_s3_object" "lambda_zip_object" {
  bucket = aws_s3_bucket.raw_data.id
  key    = "lambda_packages/transformer_lambda.zip"
  source = data.archive_file.lambda_zip.output_path

  # Only re-upload if the zip file changes
  etag = filemd5(data.archive_file.lambda_zip.output_path)
}

# The Lambda function resource
resource "aws_lambda_function" "transformer_lambda" {
  function_name = "json-to-parquet-transformer-${random_id.suffix.hex}"
  
  # Deploy from the S3 bucket
  s3_bucket = aws_s3_bucket.raw_data.id
  s3_key    = aws_s3_object.lambda_zip_object.key

  handler       = "transformer.handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_exec_role.arn
  timeout       = 30 # seconds

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # Use the public, pre-built AWSSDKPandas (awswrangler) layer for us-east-1
  layers = ["arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python39:2"]

  environment {
    variables = {
      # Pass the processed bucket name as an environment variable to the script
      DEST_BUCKET = aws_s3_bucket.processed_data.bucket
    }
  }
}

# The S3 trigger that invokes the Lambda function
resource "aws_s3_bucket_notification" "raw_data_trigger" {
  bucket = aws_s3_bucket.raw_data.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.transformer_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  # This depends_on block is important. It tells Terraform to create the Lambda
  # function and its permissions BEFORE trying to create the trigger.
  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

# Grant S3 permission to invoke the Lambda function
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transformer_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_data.arn
}
