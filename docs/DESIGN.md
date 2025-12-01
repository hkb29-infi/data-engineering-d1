# Design Choices for Pipeline

This document is the choices I made and the explanation for it when developing this ELT pipeline.

### Choosing the Lambda function for the transformation of the data 

* The Lambda function is a great choice for instant, lightweight transformations as opposed to its alternative AWS Glue job which would be preferable when dealing with large, complex data that might take hours for the ETL(Extract, Transform, Load) process that we want. Between these two, the Lambda is a serverless service, and it is more cost-effective compared to the AWS Glue Job since we only pay for the milliseconds that it runs.

### Using a Public Lambda Layer for the dependencies (such as `pandas` and `pyarrow`)
* Initially, I encountered a `Runtime error OS`. The reason behind it was that complex libraries like `pandas` and `pyarrow` were built and run on the local machine which was Windows in my case and this was incompatible with the Linux environment Lambda uses. So, the trade-off was shifting from an error-prone local build process to the widely accepted practice of using managed public layers.

### Transforming the JSON to a Parquet file format
* JSON is an inefficient format to do analysis on despite it is human-readable. The main reason is when trying to search for a specific piece of information in the data, rather than scanning a particular portion of the data, `AWS Athena` will have to scan the entire data  reducing the querying speed and increasing the cost since `AWS Athena` bills you based on the amount of data scanned . 
* However, compared to JSON, parquet files are a highly organized file formats with a storage format column-wise. This makes it efficient to scan only particular portion of the data when analysing something specific. This also makes it cost-efficient and increases the query-speed.

### Terraform was chosen as the IaC tool.
* Terraform was chosen because it uses a very clear and declarative syntax. For this project, terraform was a good choice because we can version-control and review the pipeline efficiently. 

