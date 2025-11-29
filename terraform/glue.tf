# IAM Role for AWS Glue Crawler
resource "aws_iam_role" "glue_crawler_role" {
  name = "glue-crawler-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

# Attachment 1: Attach the AWS-managed policy for required Glue service permissions
resource "aws_iam_role_policy_attachment" "glue_service_role_attach" {
  role       = aws_iam_role.glue_crawler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Attachment 2: Attach a custom policy for S3 permissions, as the managed policy does not grant S3 access.
resource "aws_iam_role_policy" "glue_s3_access_policy" {
  name = "glue-crawler-s3-access-policy-${random_id.suffix.hex}"
  role = aws_iam_role.glue_crawler_role.id

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.processed_data.arn,
          "${aws_s3_bucket.processed_data.arn}/*"
        ]
      }
    ]
  })
}

# --- AWS Glue Catalog Database ---
resource "aws_glue_catalog_database" "clickstream_database" {
  name = "clickstream_db_${random_id.suffix.hex}"
}

# --- AWS Glue Crawler ---
resource "aws_glue_crawler" "clickstream_crawler" {
  name          = "clickstream-parquet-crawler-${random_id.suffix.hex}"
  database_name = aws_glue_catalog_database.clickstream_database.name
  role          = aws_iam_role.glue_crawler_role.arn
  schedule      = "cron(0 0 * * ? *)" # Runs daily at midnight UTC, adjust if needed

  s3_target {
    path = "s3://${aws_s3_bucket.processed_data.bucket}/"
    # Crawler will automatically infer partitioning from the S3 path structure (year=YYYY/month=MM/day=DD/)
  }
}
