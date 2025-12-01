# Serverless Data Processing Pipeline

In this assessment D1, there is implementation for a serverless data processing pipeline on AWS to handle streaming clickstream data.

## Structure

The pipeline is designed with the following sequential architecture using serverless AWS components:

`Client Data -> Kinesis Firehose (Ingestion) -> Raw S3 Bucket (in JSON) -> S3 Trigger -> Lambda Function (Transformation) -> Processed S3 Bucket (in Parquet) -> Glue Crawler (defining data table) -> Athena (Querying)`

The Lambda function's dependencies (e.g., `awswrangler`, `pandas`, `pyarrow`) are dealt through managed public AWS Lambda Layer as seen in the Terraform configuration. This ensures scalability and avoids local build issues as mentioned in the design choices.

## Deliverables Checklist

- [x] IaC for the entire pipeline (`/terraform` directory)
- [x] Transformation script (`/src/transformer.py`)
- [x] README.md (this file)
- [x] Supporting material for my design choices (`/docs/DESIGN.md`)
- [x] Public Git repository with commits

## How to Run the pipeline

### Prerequisites
* AWS CLI installed and configured
* Active AWS Account
*   Terraform installed

### Deployment Steps

1.  **Clone the Repo:**
    ```bash
    git clone https://github.com/hkb29-infi/data-engineering-d1.git
    cd data-engineering-d1
    ```

2.  **Deploy the Infrastructure:**
    Go to the Terraform directory to deploy the resources and there is no installation needed for dependencies.
    ```bash
    cd terraform
    terraform init
    terraform apply
    ```
    Review the plan and type `yes` to approve. You will get an output with the name of your `firehose delivery stream`.

## How to Test

After deployment, you can send a test record to the pipeline using the included `sample-event.json` and the AWS CLI.

1.  **Get the Delivery Stream Name**: As mentioned, by running `terraform apply` you will get your `firehose delivery stream` name.

2.  **Send a Test Record via PowerShell**: The following commands will encode the content of `sample-event.json` and send it to your delivery stream.

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

    You will get a `RecordId` if the command is successful which confirms that the record was received.

## Verifying the Results

1.  **Check S3**: After using the `aws firehose put-record`, you should see a new Parquet file in your processed data bucket on your AWS S3 console, organized by date (e.g., `s3://your-processed-bucket/year=2025/month=11/day=29/...`).
2.  **Run Glue Crawler**: Manually run the Glue Crawler created by Terraform from the AWS Glue console as this will crawl the processed data and define its schema in the Glue Data Catalog.
3.  **Query with Athena**: Go to the Amazon Athena query editor, select the database created by Terraform (e.g., `clickstream_db_...`), and run the desired queries in the new table. Sample queries are given below. Make sure to select a S3 configuration to be able to run the queries in Athena.

## Sample Athena Queries

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

To make sure there are no charges running in the back, we should destroy all cloud resources we used in the pipeline when done.

1.  So we will again go to the `terraform` directory:
    ```bash
    cd terraform
    ```
2.  Run the destroy command:
    ```bash
    terraform destroy
    ```
    Review the plan and type `yes` to approve the deletion of all resources.