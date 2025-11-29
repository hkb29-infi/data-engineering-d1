# Design Decisions for the Serverless Data Processing Pipeline

This document outlines the design choices, assumptions, and trade-offs considered during the development of this ETL/ELT pipeline.

### Infrastructure as Code (IaC): Terraform

*   **Choice:** Terraform was chosen as the IaC tool.
*   **Justification:** Terraform is more reliable and widely adopted tool for infrastructure provisioning. Moreover, the syntax it has is very easy to define the state of the infrastructure. The state management capabilities give us a nice picture of the deployed resources and will also allow the entire pipeline to be version-controlled, reviewed, and deployed efficiently.

### Ingestion: Amazon Kinesis Data Firehose

*   **Choice:** Kinesis Data Firehose for data ingestion.
*   **Justification:** For a high-throughput clickstream scenario, Firehose is an ideal choice. It is a fully managed service that handles the complexities of data ingestion, batching, compression, and partitioning automatically. This significantly simplifies the architecture compared to managing a fleet of servers. Its ability to batch-save data to S3 in near real-time and partition it dynamically based on arrival time directly meets the project requirements and provides a cost-effective, scalable solution.

### Dependency Management

Dependencies for the Lambda function (such as `pandas` and `pyarrow`) are managed via a public, pre-built AWS Lambda Layer provided by AWS (`arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python39:2`). This design choice was made for several key reasons:

*   **Portability & Reproducibility:** It eliminates the need for a local build environment. The entire stack can be deployed with a single `terraform apply` command, making the project highly portable and ensuring a consistent deployment for any user.
*   **Reliability:** It completely avoids cross-platform compilation errors (e.g., building on Windows for a Linux-based Lambda environment), which was a critical issue discovered during development.
*   **Simplicity & Best Practices:** It simplifies the deployment process and follows the best practice of using managed, pre-optimized layers for common, heavy dependencies.

### Transformation Logic

The Lambda function (`transformer.py`) is written in Python 3.9 using the standard `boto3` library. Its key responsibilities are:

1.  **Event Parsing:** It receives the S3 `ObjectCreated:Put` event from the raw data bucket.
2.  **URL-Decoding the Object Key:** The S3 object key from the event is URL-decoded using `urllib.parse.unquote_plus`. This is a critical step to handle special characters (e.g., `=`) in the date-based partitioning scheme created by Kinesis Firehose.
3.  **Decompressing Data:** The function retrieves the object from the raw bucket and, since Firehose is configured to use GZIP, it decompresses the file content in-memory.
4.  **Data Transformation:** It parses the JSON data, converts it to a Pandas DataFrame, and performs any required transformations (in this case, dropping a specified column if it exists).
5.  **Writing to Parquet:** The transformed DataFrame is converted to the Parquet format and written to the processed S3 bucket, preserving the original date-based partitioning in the object key.

### Data Storage Format: Apache Parquet

*   **Choice:** The transformed data is stored in Parquet format.
*   **Justification:** Parquet is a columnar storage format optimized for analytical workloads. Compared to row-based formats like JSON, Parquet offers:
    1.  **Better Compression:** It significantly reduces the data footprint in S3, lowering storage costs.
    2.  **Improved Query Performance:** Analytical query engines like Amazon Athena can scan only the required columns, drastically reducing the amount of data read and improving query speed.
    *   This results in faster insights and lower query costs, which is a primary goal for a business intelligence use case.

### Data Catalog: AWS Glue Crawler

*   **Choice:** An AWS Glue Crawler to catalog the transformed data.
*   **Justification:** The Glue Crawler automates the process of discovering the dataset's schema and partitions in S3. It populates the AWS Glue Data Catalog with this metadata, making the data immediately available for querying in Amazon Athena. This eliminates the need for manual schema definition (e.g., `CREATE TABLE` DDL statements) and ensures that new partitions are automatically discovered and added to the table.

### Scalability and Future Improvements

*   **Scalability:** The current architecture is highly scalable. Kinesis Firehose, S3, and Lambda are all serverless components that scale automatically with the volume of incoming data.
*   **Improving the Transformation:** If transformation logic were to become more complex (e.g., requiring large external libraries, long processing times, or complex joins), the Lambda function could be replaced with an **AWS Glue ETL Job**. This would provide more processing power and a dedicated Spark environment for heavy data processing.
*   **Improving Ingestion Reliability:** For scenarios requiring stronger ordering guarantees or the ability for multiple consumers to read the stream, an **Amazon Kinesis Data Stream** could be placed in front of Kinesis Data Firehose. The Data Stream would act as a highly durable buffer, with Firehose subscribing to it as a consumer.