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

# Policy for Glue Crawler to read from S3 and write to Glue Catalog
resource "aws_iam_policy" "glue_crawler_policy" {
  name        = "glue-crawler-policy-${random_id.suffix.hex}"
  description = "Allows Glue Crawler to read from processed S3 bucket and write to Glue Catalog"

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
      },
      {
        Effect = "Allow",
        Action = [
          "glue:GetDatabase",
          "glue:CreateDatabase",
          "glue:GetDataBases",
          "glue:CreateTable",
          "glue:GetTable",
          "glue:GetTables",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:BatchCreatePartition",
          "glue:CreatePartition",
          "glue:DeletePartition",
  "glue:BatchDeletePartition",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:UpdatePartition"
        ],
        Resource = "*" # Glue permissions are often broad
      }
    ]
  })
}

# Attach the policy to the Glue Crawler role
resource "aws_iam_role_policy_attachment" "glue_crawler_attach" {
  role       = aws_iam_role.glue_crawler_role.name
  policy_arn = aws_iam_policy.glue_crawler_policy.arn
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
