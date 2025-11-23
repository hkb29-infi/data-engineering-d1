terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
resource "random_id" "suffix" {
  byte_length = 4
}
resource "aws_s3_bucket" "raw_data" {
  bucket = "clickstream-raw-data-${random_id.suffix.hex}"
  tags = {
    Name    = "Clickstream Raw Data"
    Project = "D1-Data-Pipeline"
  }
}
resource "aws_s3_bucket" "processed_data" {
  bucket = "clickstream-processed-data-${random_id.suffix.hex}"
  tags = {
    Name    = "Clickstream Processed Data"
    Project = "D1-Data-Pipeline"
  }
}
resource "aws_s3_bucket_public_access_block" "raw_data_pac" {
  bucket = aws_s3_bucket.raw_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}