import boto3
import urllib.parse
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
import json
import gzip
import io
import os

# Initialize the S3 client
s3_client = boto3.client('s3')

def handler(event, context):
    """
    This function is triggered by an S3 event. It reads a gzipped JSON file
    from the source bucket, transforms it to Parquet, and writes it to the
    destination bucket.
    """
    print("Event received:", json.dumps(event))

    # Get the destination bucket name from an environment variable
    # We will set this environment variable in our Terraform code
    dest_bucket_name = os.environ['DEST_BUCKET']

    for record in event['Records']:
        # Get the source bucket name and object key from the S3 event
        source_bucket_name = record['s3']['bucket']['name']
        
        # S3 object keys with special characters are URL-encoded in the event.
        # We must decode the key before using it.
        object_key = urllib.parse.unquote_plus(record['s3']['object']['key'], encoding='utf-8')

        print(f"Processing object {object_key} from bucket {source_bucket_name}")

        try:
            # Get the gzipped object from the raw S3 bucket
            response = s3_client.get_object(Bucket=source_bucket_name, Key=object_key)
            gzipped_content = response['Body'].read()

            # Decompress the content in-memory
            with gzip.GzipFile(fileobj=io.BytesIO(gzipped_content), mode='rb') as f:
                json_content = f.read().decode('utf-8')

            # The content is a single JSON object sent by Firehose.
            # We'll parse it and put it into a list so it can be read into a DataFrame.
            data = [json.loads(json_content)]

            # Convert the list of dictionaries to a Pandas DataFrame
            df = pd.DataFrame(data)
            print(f"Successfully created DataFrame with {len(df)} rows")

            # --- Your Transformation Logic Goes Here ---
            # For example, let's remove a field called 'unwanted_field' if it exists
            if 'unwanted_field' in df.columns:
                df = df.drop(columns=['unwanted_field'])
                print("Removed column 'unwanted_field'")
            # ------------------------------------------

            # Convert the DataFrame to a Parquet file in-memory
            parquet_buffer = io.BytesIO()
            df.to_parquet(parquet_buffer, index=False)
            
            # Reset buffer's position to the beginning
            parquet_buffer.seek(0)

            # Construct the destination key for the Parquet file
            # e.g., raw/file.json.gz -> processed/file.parquet
            dest_object_key = os.path.splitext(object_key)[0] + '.parquet'
            
            # The object_key from Firehose includes the date partitions.
            # We want to preserve them in the destination.
            # e.g., year=2025/month=11/day=23/file.json.gz -> year=2025/month=11/day=23/file.parquet
            
            # Upload the Parquet file to the processed bucket
            s3_client.put_object(
                Bucket=dest_bucket_name,
                Key=dest_object_key,
                Body=parquet_buffer.getvalue()
            )
            print(f"Successfully wrote Parquet file to s3://{dest_bucket_name}/{dest_object_key}")

        except Exception as e:
            print(f"Error processing object {object_key}: {e}")
            raise e

    return {
        'statusCode': 200,
        'body': json.dumps('Processing complete')
    }