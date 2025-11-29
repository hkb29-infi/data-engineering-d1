# Serverless Data Processing Pipeline

This assessment consists of a serverless data processing pipeline on AWS to handle streaming clickstream data as structured in Assignment D1.

## Architecture

The pipeline is designed with the following event-driven architecture using serverless AWS components:

`Client Data -> Kinesis Firehose -> Raw S3 Bucket (JSON) -> S3 Trigger -> Lambda Function (Transform) -> Processed S3 Bucket (Parquet) -> Glue Crawler -> Athena`

The Lambda function's dependencies (e.g., `awswrangler`) are managed via a pre-built, public AWS Lambda Layer, which is referenced in the Terraform configuration. This ensures portability and avoids local build issues.

## Deliverables Checklist

- [x] IaC for the entire pipeline (`/terraform` directory)
- [x] Transformation script (`/src/transformer.py`)
- [x] README.md with instructions and sample queries (this file)
- [x] Supporting material for design choices (`/docs/DESIGN.md`)
- [x] Public Git repository with commit history

## How to Deploy

### Prerequisites
*   An active AWS Account
*   Terraform installed
*   AWS CLI installed and configured with credentials (`aws configure`)

### Deployment Steps

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/hkb29-infi/data-engineering-d1.git
    cd data-engineering-d1
    ```

2.  **Deploy the Infrastructure:**
    Navigate to the Terraform directory and deploy all resources. There are no local dependencies to install.
    ```bash
    cd terraform
    terraform init
    terraform apply
    ```
    Review the plan and type `yes` to approve. Note the output name of the `firehose_delivery_stream_name`.

## How to Test

After deployment, you can send a test record to the pipeline using the included `sample-event.json` and the AWS CLI.

1.  **Get the Delivery Stream Name**: The name of the delivery stream is an output of the Terraform deployment. Look for the `firehose_delivery_stream_name` output.

2.  **Send a Test Record (using PowerShell)**: The following commands will encode the content of `sample-event.json` and send it to your delivery stream.

    ```powershell
    # IMPORTANT: Replace <YOUR_DELIVERY_STREAM_NAME> with the actual stream name from the terraform output.
    $delivery_stream_name = "<YOUR_DELIVERY_STREAM_NAME>"

    # Read the sample event file, encode it, and create the JSON payload for the CLI
    $json_data = (Get-Content -Raw -Path ../sample-event.json)
    $encoded_data = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($json_data))
    $record_payload = @{ Data = $encoded_data }
    $record_json_string = $record_payload | ConvertTo-Json -Compress

    # Build and execute the final command
    aws firehose put-record --delivery-stream-name $delivery_stream_name --record $record_json_string
    ```

    A successful command will return a `RecordId`, confirming the record was received.

## Verifying the Results

1.  **Check S3**: After a minute or two, you should see a new Parquet file in your processed data bucket, organized by date (e.g., `s3://your-processed-bucket/year=2025/month=11/day=27/...`).
2.  **Run Glue Crawler**: Manually run the Glue Crawler created by Terraform from the AWS Glue console. This will crawl the processed data and define its schema in the Glue Data Catalog.
3.  **Query with Athena**: Go to the Amazon Athena query editor, select the database created by Terraform (e.g., `clickstream_db_...`), and run a query against the new table.

## Sample Athena Queries

**Note:** Replace `"your_athena_table_name"` with the actual table name created by your Glue Crawler.

**1. Verify All Data and Schema**
```sql
SELECT * FROM "your_athena_table_name" LIMIT 10;
```

**2. Sample Analysis: Count Events by Type**
```sql
SELECT event_type, COUNT(*) as event_count
FROM "your_athena_table_name"
GROUP BY event_type
ORDER BY event_count DESC;
```

## How to Clean Up

To avoid ongoing charges, destroy all cloud resources when you are finished.

1.  Navigate to the `terraform` directory:
    ```bash
    cd terraform
    ```
2.  Run the destroy command:
    ```bash
    terraform destroy
    ```
    Review the plan and type `yes` to approve the deletion of all resources.