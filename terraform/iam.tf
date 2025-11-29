# IAM Role for Kinesis Firehose to access the S3 bucket
resource "aws_iam_role" "firehose_role" {
  name = "firehose-s3-delivery-role-${random_id.suffix.hex}"

  # This assume_role_policy allows the Firehose service to assume this role
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })
}

# The policy that grants the role permission to write to S3
resource "aws_iam_policy" "firehose_policy" {
  name        = "firehose-s3-delivery-policy-${random_id.suffix.hex}"
  description = "Allows Kinesis Firehose to write to the raw data S3 bucket"

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ],
        Resource = [
          aws_s3_bucket.raw_data.arn,
          "${aws_s3_bucket.raw_data.arn}/*" # Important: allows writing objects inside the bucket
        ]
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "firehose_attach" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_policy.arn
}

# --- Lambda IAM Role Starts Here ---

# IAM Role for the Lambda function
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-s3-transformer-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Policy granting the Lambda function necessary permissions
resource "aws_iam_policy" "lambda_exec_policy" {
  name        = "lambda-s3-transformer-policy-${random_id.suffix.hex}"
  description = "Allows Lambda to read from raw bucket, write to processed bucket, and write logs"

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        # Permissions for CloudWatch logging
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        # Permissions for awswrangler to read from the raw bucket and write to the processed bucket
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.raw_data.arn,
          "${aws_s3_bucket.raw_data.arn}/*",
          aws_s3_bucket.processed_data.arn,
          "${aws_s3_bucket.processed_data.arn}/*"
        ]
      }
    ]
  })
}

# Attach the policy to the Lambda role
resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_exec_policy.arn
}