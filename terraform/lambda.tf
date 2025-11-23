# This data source zips the entire 'src' directory, including the script and its dependencies
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src" # Points to the 'src' directory
  output_path = "${path.module}/lambda_package.zip"
}

# The Lambda function resource
resource "aws_lambda_function" "transformer_lambda" {
  function_name = "json-to-parquet-transformer-${random_id.suffix.hex}"
  filename      = data.archive_file.lambda_zip.output_path
  handler       = "transformer.handler" # The file is 'transformer.py', the function is 'handler'
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_exec_role.arn
  timeout       = 30 # seconds

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

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
    # Optional: only trigger for files in a specific folder
    # filter_prefix       = "some/folder/"
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
